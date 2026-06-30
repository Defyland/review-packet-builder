# frozen_string_literal: true

module ReviewPacketBuilder
  module PacketIndex
    module_function

    def render(project_name:, prompt_id:, report:, artifacts:, commands:, provenance:, generated_at:)
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

        ## Provenance

        #{render_provenance(provenance)}

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

    def render_provenance(provenance)
      project_line = render_snapshot("target repo", provenance.fetch(:project))
      tool_lines = provenance.fetch(:tools).map do |tool_name, snapshot|
        render_snapshot(tool_name.to_s.tr("_", "-"), snapshot)
      end

      ([project_line] + tool_lines).join("\n")
    end

    def render_snapshot(label, snapshot)
      root = snapshot.fetch(:root)
      branch = snapshot[:git_branch]
      commit = snapshot[:git_commit]
      dirty = snapshot[:git_dirty]

      details =
        if branch && commit && dirty
          "`#{branch}` @ `#{commit}` (`#{dirty}`)"
        else
          "git unavailable"
        end

      "- `#{label}`: `#{root}` - #{details}"
    end
  end
end
