# frozen_string_literal: true

require "fzy"

# Not a parity test: upstream Biblioteca has no test suite (see TEST_PARITY.md).
# These pin lib/fzy.rb, a port of src/sidebar/fzy.js, because its output is the
# order of every search result and a one-constant slip is invisible until the
# wrong row is on top.
RSpec.describe Fzy, :extra do
  describe ".match?" do
    it "accepts a needle whose characters appear in order" do
      expect(described_class.match?("abc", "aXbXc")).to be(true)
    end

    it "rejects a needle whose characters appear out of order" do
      expect(described_class.match?("abc", "acb")).to be(false)
    end

    it "rejects a needle longer than the haystack" do
      expect(described_class.match?("abc", "ab")).to be(false)
    end

    it "accepts an empty needle" do
      expect(described_class.match?("", "x")).to be(true)
    end

    # The caller case-folds both sides when the search term is all lower case
    # (SearchView's smart-case rule), so this method itself is exact.
    it "compares case-sensitively" do
      expect(described_class.match?("AB", "ab")).to be(false)
    end
  end

  describe ".score" do
    it "returns SCORE_MIN for an empty needle" do
      expect(described_class.score("", "abc")).to eq(described_class::SCORE_MIN)
    end

    it "returns SCORE_MIN for an empty haystack" do
      expect(described_class.score("abc", "")).to eq(described_class::SCORE_MIN)
    end

    it "returns SCORE_MAX when the needle is the whole haystack" do
      expect(described_class.score("abc", "abc")).to eq(described_class::SCORE_MAX)
    end

    it "returns SCORE_MIN for a haystack longer than MAX_HAYSTACK" do
      expect(described_class.score("a", "a" * (described_class::MAX_HAYSTACK + 1)))
        .to eq(described_class::SCORE_MIN)
    end

    # 0.9 for the leading slash bonus, 1.0 for the consecutive match, then one
    # trailing gap of -0.005 for the unmatched "c".
    it "credits the leading-slash bonus and the consecutive-match bonus" do
      expect(described_class.score("ab", "abc")).to be_within(1e-9).of(1.895)
    end

    # 0.9 + 0.8 (word bonus, the character after "_") and no trailing gap.
    it "credits the word bonus after an underscore" do
      expect(described_class.score("ab", "a_b")).to be_within(1e-9).of(1.69)
    end

    # 0.9 + 0 (no bonus after "X") - 0.01 for the inner gap.
    it "charges an inner gap and credits no bonus mid-word" do
      expect(described_class.score("ab", "aXb")).to be_within(1e-9).of(0.89)
    end

    it "charges one inner gap per skipped character" do
      expect(described_class.score("ab", "aXXXXXXXXb")).to be_within(1e-9).of(0.82)
    end

    it "credits the camel-case bonus on a lower-to-upper transition" do
      expect(described_class.score("GtkWidget", "GtkWidgetClass"))
        .to be_within(1e-9).of(8.874999999999996)
    end
  end

  # The behaviour a user sees: of two candidates that both match, the one whose
  # matched characters are more consecutive comes first.
  describe "ranking" do
    it "puts gtk_widget_show above gtk_widget_get_show for gtkwidgetshow" do
      %w[gtk_widget_show gtk_widget_get_show]
        .map { |haystack| described_class.score("gtkwidgetshow", haystack) }
        .then do |exact, padded|
          expect(exact).to be > padded
        end
    end

    it "scores gtkwidgetshow against gtk_widget_show at 12.48" do
      expect(described_class.score("gtkwidgetshow", "gtk_widget_show"))
        .to be_within(1e-9).of(12.480000000000002)
    end
  end
end
