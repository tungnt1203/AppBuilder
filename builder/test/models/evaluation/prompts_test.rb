require "test_helper"

class Evaluation::PromptsTest < ActiveSupport::TestCase
  test "the same seed picks the same sample" do
    prompts = 20.times.map { |index| { "id" => format("p%03d", index + 1), "name" => "App #{index}", "language" => "vi", "request" => "..." } }
    with_prompts(prompts) do
      first = Evaluation::Prompts.sample(5, seed: 1).map { |prompt| prompt[:id] }
      assert_equal first, Evaluation::Prompts.sample(5, seed: 1).map { |prompt| prompt[:id] }
      assert_not_equal first, Evaluation::Prompts.sample(5, seed: 2).map { |prompt| prompt[:id] }
      assert_equal 5, first.uniq.size
    end
  end

  test "the share of what was asked that the app visibly does leaves out what can't be seen" do
    judge = { "asked" => [ { "verdict" => "met" }, { "verdict" => "met" }, { "verdict" => "missed" }, { "verdict" => "unclear" } ] }
    assert_equal 67, Evaluation::Judge.asked_rate(judge)
    assert_nil Evaluation::Judge.asked_rate({ "asked" => [ { "verdict" => "unclear" } ] })
    assert_nil Evaluation::Judge.asked_rate(nil)
  end

  private
    def with_prompts(prompts)
      original = Evaluation::Prompts.method(:all)
      Evaluation::Prompts.define_singleton_method(:all) { prompts.map(&:with_indifferent_access) }
      yield
    ensure
      Evaluation::Prompts.define_singleton_method(:all, original)
    end
end
