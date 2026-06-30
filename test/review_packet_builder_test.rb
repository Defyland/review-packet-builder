# frozen_string_literal: true

require "test_helper"

class ReviewPacketBuilderTest < Minitest::Test
  FIXTURES_ROOT = File.expand_path("fixtures", __dir__)

  def test_build_generates_packet_artifacts_from_fixture_tools
    Dir.mktmpdir do |dir|
      builder = isolated_fixture_builder(dir)

      result = builder.build(
        project_path: isolated_fixture_project_path(dir),
        output_dir: File.join(dir, "demo-packet")
      )

      artifacts = result.fetch(:artifacts)
      assert File.file?(artifacts.fetch(:context_pack))
      assert File.file?(artifacts.fetch(:readiness_markdown))
      assert File.file?(artifacts.fetch(:readiness_json))
      assert File.file?(artifacts.fetch(:prompt))
      assert File.file?(artifacts.fetch(:packet))

      prompt = File.read(artifacts.fetch(:prompt))
      assert_includes prompt, "Repository: demo-repo"
      assert_includes prompt, "Read context-pack.md and readiness.md"

      packet = File.read(artifacts.fetch(:packet))
      assert_includes packet, "Review Packet for `demo-repo`"
      assert_includes packet, "Pass/Warn/Fail: `8 / 1 / 1`"
      assert_includes packet, "[context-pack.md](./context-pack.md)"
      assert_includes packet, "## Provenance"
      assert_includes packet, "`target repo`:"
      assert_includes packet, "git unavailable"
      assert_includes packet, "prompt-registry/bin/prompt-registry materialize release-readiness"
    end
  end

  def test_packet_surfaces_non_pass_rules
    Dir.mktmpdir do |dir|
      result = isolated_fixture_builder(dir).build(
        project_path: isolated_fixture_project_path(dir),
        output_dir: File.join(dir, "demo-packet"),
        prompt_id: "review"
      )

      packet = File.read(result.fetch(:artifacts).fetch(:packet))
      assert_includes packet, "`docs.architecture` (`warn`): Architecture note is missing"
      assert_includes packet, "`release.git` (`fail`): Git worktree is dirty"
      assert_includes packet, "Prompt: `review@v1`"
    end
  end

  def test_cli_uses_default_output_dir_and_reports_written_packet
    captured = {}
    fake_builder = Object.new
    fake_builder.define_singleton_method(:build) do |**kwargs|
      captured.merge!(kwargs)
      {
        project_name: "demo-repo",
        output_dir: kwargs.fetch(:output_dir),
        artifacts: { packet: File.join(kwargs.fetch(:output_dir), "packet.md") }
      }
    end

    stdout = StringIO.new
    stderr = StringIO.new
    cli = ReviewPacketBuilder::CLI.new(
      [fixture_project_path],
      stdout: stdout,
      stderr: stderr,
      builder_factory: ->(**_kwargs) { fake_builder }
    )

    status = cli.call

    assert_equal 0, status
    assert_equal fixture_project_path, captured.fetch(:project_path)
    assert_equal File.join("tmp", "demo-repo-packet"), captured.fetch(:output_dir)
    assert_includes stdout.string, "tmp/demo-repo-packet/packet.md"
    assert_empty stderr.string
  end

  def test_cli_accepts_custom_tool_roots
    captured = {}
    fake_builder = Object.new
    fake_builder.define_singleton_method(:build) do |**kwargs|
      captured[:build] = kwargs
      {
        project_name: "demo-repo",
        output_dir: kwargs.fetch(:output_dir),
        artifacts: { packet: File.join(kwargs.fetch(:output_dir), "packet.md") }
      }
    end

    builder_factory_args = {}
    stdout = StringIO.new
    stderr = StringIO.new
    cli = ReviewPacketBuilder::CLI.new(
      [
        "--context-pack-builder-root", "fixtures/cpb",
        "--eval-harness-root", "fixtures/eh",
        "--prompt-registry-root", "fixtures/pr",
        "--output", "tmp/custom-packet",
        fixture_project_path
      ],
      stdout: stdout,
      stderr: stderr,
      builder_factory: lambda do |**kwargs|
        builder_factory_args.merge!(kwargs)
        fake_builder
      end
    )

    status = cli.call

    assert_equal 0, status
    assert_equal "fixtures/cpb", builder_factory_args.fetch(:context_pack_builder_root)
    assert_equal "fixtures/eh", builder_factory_args.fetch(:eval_harness_root)
    assert_equal "fixtures/pr", builder_factory_args.fetch(:prompt_registry_root)
    assert_equal "tmp/custom-packet", captured.fetch(:build).fetch(:output_dir)
    assert_empty stderr.string
  end

  def test_build_surfaces_git_provenance_when_sources_are_git_repos
    Dir.mktmpdir do |dir|
      project_root = copy_fixture_tree("demo-repo", dir)
      cpb_root = copy_fixture_tree("context-pack-builder", dir)
      eval_root = copy_fixture_tree("eval-harness", dir)
      prompt_root = copy_fixture_tree("prompt-registry", dir)

      project_commit = initialize_git_repo!(project_root)
      cpb_commit = initialize_git_repo!(cpb_root)
      eval_commit = initialize_git_repo!(eval_root)
      prompt_commit = initialize_git_repo!(prompt_root)

      builder = ReviewPacketBuilder::PacketBuilder.new(
        context_pack_builder_root: cpb_root,
        eval_harness_root: eval_root,
        prompt_registry_root: prompt_root,
        ruby_executable: RbConfig.ruby
      )

      result = builder.build(
        project_path: project_root,
        output_dir: File.join(dir, "git-packet")
      )

      packet = File.read(result.fetch(:artifacts).fetch(:packet))
      assert_includes packet, "`main` @ `#{project_commit}` (`clean`)"
      assert_includes packet, "`main` @ `#{cpb_commit}` (`clean`)"
      assert_includes packet, "`main` @ `#{eval_commit}` (`clean`)"
      assert_includes packet, "`main` @ `#{prompt_commit}` (`clean`)"
    end
  end

  private

  def fixture_builder
    ReviewPacketBuilder::PacketBuilder.new(
      context_pack_builder_root: File.join(FIXTURES_ROOT, "context-pack-builder"),
      eval_harness_root: File.join(FIXTURES_ROOT, "eval-harness"),
      prompt_registry_root: File.join(FIXTURES_ROOT, "prompt-registry"),
      ruby_executable: RbConfig.ruby
    )
  end

  def fixture_project_path
    File.join(FIXTURES_ROOT, "demo-repo")
  end

  def isolated_fixture_builder(root)
    ReviewPacketBuilder::PacketBuilder.new(
      context_pack_builder_root: copy_fixture_tree("context-pack-builder", root),
      eval_harness_root: copy_fixture_tree("eval-harness", root),
      prompt_registry_root: copy_fixture_tree("prompt-registry", root),
      ruby_executable: RbConfig.ruby
    )
  end

  def isolated_fixture_project_path(root)
    copy_fixture_tree("demo-repo", root)
  end

  def copy_fixture_tree(name, root)
    source = File.join(FIXTURES_ROOT, name)
    destination = File.join(root, name)
    FileUtils.cp_r(source, destination)
    destination
  end

  def initialize_git_repo!(path)
    run_git!(path, "init", "-b", "main")
    run_git!(path, "config", "user.name", "Codex Test")
    run_git!(path, "config", "user.email", "codex-test@example.com")
    run_git!(path, "add", ".")
    run_git!(path, "commit", "-m", "Fixture commit")
    capture_git!(path, "rev-parse", "--short=12", "HEAD")
  end

  def run_git!(path, *args)
    stdout, stderr, status = Open3.capture3("git", "-C", path, *args)
    return stdout if status.success?

    raise "git #{args.join(' ')} failed:\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
  end

  def capture_git!(path, *args)
    run_git!(path, *args).strip
  end
end
