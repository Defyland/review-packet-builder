# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"
require "time"

module ReviewPacketBuilder
  class PacketBuilder
    REPO_ROOT = File.expand_path("../..", __dir__)
    WORKSPACE_ROOT = File.expand_path("..", REPO_ROOT)
    DEFAULT_CONTEXT_PACK_BUILDER_ROOT = File.join(WORKSPACE_ROOT, "context-pack-builder")
    DEFAULT_EVAL_HARNESS_ROOT = File.join(WORKSPACE_ROOT, "eval-harness")
    DEFAULT_PROMPT_REGISTRY_ROOT = File.join(WORKSPACE_ROOT, "prompt-registry")
    DEFAULT_RUBY_EXECUTABLE = RbConfig.ruby

    def initialize(
      context_pack_builder_root: DEFAULT_CONTEXT_PACK_BUILDER_ROOT,
      eval_harness_root: DEFAULT_EVAL_HARNESS_ROOT,
      prompt_registry_root: DEFAULT_PROMPT_REGISTRY_ROOT,
      ruby_executable: DEFAULT_RUBY_EXECUTABLE
    )
      @context_pack_builder_root = File.expand_path(context_pack_builder_root)
      @eval_harness_root = File.expand_path(eval_harness_root)
      @prompt_registry_root = File.expand_path(prompt_registry_root)
      @ruby_executable = ruby_executable
    end

    def build(project_path:, output_dir:, prompt_id: "release-readiness", task_context: nil, constraints: nil, verification: nil)
      project_root = File.expand_path(project_path)
      raise ArgumentError, "project path does not exist: #{project_root}" unless Dir.exist?(project_root)

      packet_dir = File.expand_path(output_dir)
      FileUtils.mkdir_p(packet_dir)

      repo_name = File.basename(project_root)
      artifacts = artifact_paths(packet_dir)
      commands = []

      run_command(
        [@ruby_executable, cli_path(@context_pack_builder_root, "context-pack-builder"), project_root, "--output", artifacts[:context_pack]],
        commands
      )
      run_command(
        [@ruby_executable, cli_path(@eval_harness_root, "eval-harness"), project_root, "--output", artifacts[:readiness_markdown]],
        commands
      )
      run_command(
        [@ruby_executable, cli_path(@eval_harness_root, "eval-harness"), project_root, "--format", "json", "--output", artifacts[:readiness_json]],
        commands
      )

      report = JSON.parse(File.read(artifacts[:readiness_json])).fetch("reports").fetch(0)
      prompt_values = {
        "repo_name" => repo_name,
        "task_context" => task_context || default_task_context(repo_name, prompt_id),
        "constraints" => constraints || default_constraints(prompt_id),
        "verification" => verification || default_verification
      }

      prompt_output = run_command(prompt_command(prompt_id, prompt_values), commands)
      File.write(artifacts[:prompt], prompt_output)
      File.write(
        artifacts[:packet],
        PacketIndex.render(
          project_name: repo_name,
          prompt_id: prompt_id,
          report: report,
          artifacts: artifacts,
          commands: commands,
          generated_at: Time.now.utc.iso8601
        )
      )

      {
        project_name: repo_name,
        output_dir: packet_dir,
        artifacts: artifacts,
        report: report,
        commands: commands
      }
    end

    private

    def artifact_paths(packet_dir)
      {
        context_pack: File.join(packet_dir, "context-pack.md"),
        readiness_markdown: File.join(packet_dir, "readiness.md"),
        readiness_json: File.join(packet_dir, "readiness.json"),
        prompt: File.join(packet_dir, "prompt.md"),
        packet: File.join(packet_dir, "packet.md")
      }
    end

    def prompt_command(prompt_id, values)
      command = [@ruby_executable, cli_path(@prompt_registry_root, "prompt-registry"), "materialize", prompt_id]
      values.each do |key, value|
        command.concat(["--var", "#{key}=#{value}"])
      end
      command
    end

    def cli_path(repo_root, executable_name)
      path = File.join(repo_root, "bin", executable_name)
      raise ArgumentError, "missing sibling CLI: #{path}" unless File.file?(path)

      path
    end

    def run_command(command, commands)
      stdout, stderr, status = Open3.capture3(*command)
      commands << Shellwords.join(command)
      return stdout if status.success?

      message = stderr.strip
      message = stdout.strip if message.empty?
      raise "#{File.basename(command[1])} failed: #{message}"
    end

    def default_task_context(repo_name, prompt_id)
      case prompt_id
      when "release-readiness"
        "Assess whether #{repo_name} is actually ready to be operated or published from the current repository state."
      when "review"
        "Review the current repository state in #{repo_name} using the generated packet artifacts."
      else
        "Operate on #{repo_name} using the generated packet artifacts."
      end
    end

    def default_constraints(prompt_id)
      case prompt_id
      when "release-readiness"
        "Default to skeptical validation. Treat readiness claims as false until the repository proves them."
      when "review"
        "Default to skeptical validation. Focus on real bugs, regressions, missing tests, and contract drift first."
      else
        "Keep the scope tight, direct, and evidence-based."
      end
    end

    def default_verification
      "Read context-pack.md and readiness.md, then rerun the concrete repo contract commands they reference before concluding."
    end
  end
end
