# frozen_string_literal: true

require "optparse"

module ReviewPacketBuilder
  class CLI
    def initialize(argv, stdout:, stderr:, builder_factory: nil)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
      @builder_factory = builder_factory || ->(**kwargs) { PacketBuilder.new(**kwargs) }
    end

    def call
      options, parser = parse(@argv)
      builder = @builder_factory.call(
        context_pack_builder_root: options.fetch(:context_pack_builder_root),
        eval_harness_root: options.fetch(:eval_harness_root),
        prompt_registry_root: options.fetch(:prompt_registry_root),
        ruby_executable: options.fetch(:ruby_executable)
      )
      result = builder.build(
        project_path: options.fetch(:project_path),
        output_dir: options.fetch(:output_dir),
        prompt_id: options.fetch(:prompt_id),
        task_context: options[:task_context],
        constraints: options[:constraints],
        verification: options[:verification]
      )

      @stdout.puts "Wrote packet for #{result.fetch(:project_name)} to #{result.fetch(:output_dir)}"
      @stdout.puts result.fetch(:artifacts).fetch(:packet)
      0
    rescue OptionParser::ParseError, ArgumentError, RuntimeError => error
      @stderr.puts "error: #{error.message}"
      @stderr.puts parser ? parser.to_s : usage
      64
    end

    private

    def parse(argv)
      options = {
        prompt_id: "release-readiness",
        context_pack_builder_root: PacketBuilder::DEFAULT_CONTEXT_PACK_BUILDER_ROOT,
        eval_harness_root: PacketBuilder::DEFAULT_EVAL_HARNESS_ROOT,
        prompt_registry_root: PacketBuilder::DEFAULT_PROMPT_REGISTRY_ROOT,
        ruby_executable: PacketBuilder::DEFAULT_RUBY_EXECUTABLE
      }

      parser = OptionParser.new do |opts|
        opts.banner = usage
        opts.on("--output DIR", "Packet output directory") { |dir| options[:output_dir] = dir }
        opts.on("--prompt ID", "Prompt id from prompt-registry (default: release-readiness)") do |id|
          options[:prompt_id] = id
        end
        opts.on("--task-context TEXT", "Override the default task context") { |text| options[:task_context] = text }
        opts.on("--constraints TEXT", "Override the default constraints") { |text| options[:constraints] = text }
        opts.on("--verification TEXT", "Override the default verification instructions") do |text|
          options[:verification] = text
        end
        opts.on("--context-pack-builder-root PATH", "Path to the sibling context-pack-builder repo") do |path|
          options[:context_pack_builder_root] = path
        end
        opts.on("--eval-harness-root PATH", "Path to the sibling eval-harness repo") do |path|
          options[:eval_harness_root] = path
        end
        opts.on("--prompt-registry-root PATH", "Path to the sibling prompt-registry repo") do |path|
          options[:prompt_registry_root] = path
        end
        opts.on("--ruby EXECUTABLE", "Ruby executable used to run the sibling CLIs") do |executable|
          options[:ruby_executable] = executable
        end
      end

      parser.parse!(argv)
      project_path = argv.shift
      raise OptionParser::ParseError, "project path is required" if project_path.to_s.empty?

      repo_name = File.basename(File.expand_path(project_path))
      options[:project_path] = project_path
      options[:output_dir] ||= File.join("tmp", "#{repo_name}-packet")
      [options, parser]
    end

    def usage
      <<~USAGE
        Usage:
          review-packet-builder [options] PROJECT_PATH
      USAGE
    end
  end
end
