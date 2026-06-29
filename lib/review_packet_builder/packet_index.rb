# frozen_string_literal: true

module ReviewPacketBuilder
  module PacketIndex
    module_function

    def render(project_name:, prompt_id:, report:, artifacts:, commands:, generated_at:)
      summary = report.fetch("summary")
      non_pass_rules = Array(report.fetch("rules")).select do |rule|
        %w[warn fail].include?(rule.fetch("status"))
      end

      <<~MARKDOWN
        # Review Packet for `#{project_name}`

        Generated at: `#{generated_at}`
        Prompt: `#{prompt_id}@v1`
        Ready: `#{summary.fetch("ready") ? "yes" : "no"}`
        Pass/Warn/Fail: `#{summary.fetch("pass")} / #{summary.fetch("warn")} / #{summary.fetch("fail")}`

        ## Artifacts

        - [context-pack.md](./#{File.basename(artifacts.fetch(:context_pack))})
        - [readiness.md](./#{File.basename(artifacts.fetch(:readiness_markdown))})
        - [readiness.json](./#{File.basename(artifacts.fetch(:readiness_json))})
        - [prompt.md](./#{File.basename(artifacts.fetch(:prompt))})

        ## Non-Pass Rules

        #{render_non_pass_rules(non_pass_rules)}

        ## Commands Executed

        ```sh
        #{commands.join("\n")}
        ```

        ## Suggested Operator Flow

        1. Read `prompt.md` first.
        2. Attach or inspect `context-pack.md` and `readiness.md` before editing or reviewing.
        3. Rerun the concrete repo contract commands referenced in those artifacts before concluding.
      MARKDOWN
    end

    def render_non_pass_rules(non_pass_rules)
      return "- None. `eval-harness` reported no warn/fail rules." if non_pass_rules.empty?

      non_pass_rules.map do |rule|
        "- `#{rule.fetch("id")}` (`#{rule.fetch("status")}`): #{rule.fetch("message")}"
      end.join("\n")
    end
  end
end
