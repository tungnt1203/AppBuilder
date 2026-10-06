require "digest"

# One run of bin/eval: every sample request in eval/cases.yml is built as a real
# project, the way the studio builds it, then checked (Evaluation::Attempt). What
# came out is kept in storage/evals/<id>/ and compared with the run before it.
module Evaluation
  class Run
    ROOT = Rails.root.join("storage/evals")
    CASES = Rails.root.join("eval/cases.yml")

    attr_reader :id, :cases, :results, :meta

    def self.cases
      YAML.load_file(CASES).map(&:with_indifferent_access)
    end

    def self.ids
      ROOT.exist? ? ROOT.children.select { |dir| dir.join("results.json").exist? }.map { |dir| dir.basename.to_s }.sort : []
    end

    def self.load(id)
      JSON.parse(ROOT.join(id, "results.json").read)
    end

    def initialize(cases:, concurrency: 3, note: nil)
      @cases, @concurrency = cases, concurrency
      @id = Time.current.strftime("%Y%m%d-%H%M")
      @results = []
      @meta = { "id" => id, "note" => note, "started_at" => Time.current.iso8601, "agent_backend" => Rails.configuration.x.agent_backend,
                "builder" => version_of(Rails.root), "template" => version_of(Rails.configuration.x.template_path),
                "prompt" => Digest::SHA256.hexdigest(Rails.configuration.x.agent[:append_system_prompt].to_s).first(8) }
    end

    def dir
      ROOT.join(id)
    end

    # Projects are created one by one (each takes the next free port), then built in parallel.
    def call(&progress)
      dir.mkpath
      attempts = cases.map { |eval_case| Attempt.new(self, eval_case) }
      attempts.each(&:create_project)

      queue = Queue.new
      attempts.each { |attempt| queue << attempt }
      queue.close
      lock = Mutex.new

      @concurrency.times.map do
        Thread.new do
          while (attempt = queue.pop)
            result = Rails.application.executor.wrap { attempt.call }
            lock.synchronize { @results << result; save; progress&.call(result) }
          end
        end
      end.each(&:join)

      @meta["finished_at"] = Time.current.iso8601
      save
      self
    end

    def save
      order = cases.map { |eval_case| eval_case[:id] }
      data = meta.merge("cases" => results.sort_by { |result| order.index(result["id"]) || 0 })
      dir.join("results.json").write(JSON.pretty_generate(data))
    end

    private
      def version_of(path)
        sha = ProjectShell.new(path).capture("git", "rev-parse", "--short", "HEAD").first.strip
        dirty = ProjectShell.new(path).capture("git", "status", "--porcelain").first.present?
        dirty ? "#{sha}+changes" : sha
      end
  end
end
