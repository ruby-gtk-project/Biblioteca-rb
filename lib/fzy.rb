# frozen_string_literal: true

# Fzy is the fuzzy matcher the sidebar's search filters and ranks with.
#
# Ported from upstream's src/sidebar/fzy.js, which is itself a vendored copy of
# https://github.com/jhawthorn/fzy.js (MIT, © 2014 John Hawthorn). The scoring
# constants, the word-boundary bonus table and the dynamic-programming
# recurrence are unchanged; only the Ruby spelling differs.
#
# JavaScript's Number.MIN_SAFE_INTEGER / MAX_SAFE_INTEGER stand in for fzy's
# -infinity / +infinity sentinels. They are kept at exactly those values so a
# score computed here orders rows the same way upstream's does, and so an
# unscored row (DocumentationPage#score starts at SCORE_MIN) sorts below every
# row the current search did score.
module Fzy
  SCORE_MIN = -9_007_199_254_740_991
  SCORE_MAX = 9_007_199_254_740_991

  SCORE_GAP_LEADING = -0.005
  SCORE_GAP_TRAILING = -0.005
  SCORE_GAP_INNER = -0.01
  SCORE_MATCH_CONSECUTIVE = 1.0
  SCORE_MATCH_SLASH = 0.9
  SCORE_MATCH_WORD = 0.8
  SCORE_MATCH_CAPITAL = 0.7
  SCORE_MATCH_DOT = 0.6

  # Candidates longer than this match but are never scored: upstream refuses to
  # run the O(n*m) recurrence over them and lets them rank below everything
  # that did get a real score.
  MAX_HAYSTACK = 1024

  class << self
    # True when every character of `needle` appears in `haystack` in order.
    # This is the cheap test the filter model runs over every row; `score` is
    # only called for the rows that pass it.
    #
    # An empty needle matches, which is what upstream's loop does too.
    def match?(needle, haystack)
      needle.each_char
            .reduce(0) { |from, char| from && haystack.index(char, from)&.succ }
            .then { |reached| !reached.nil? }
    end

    # The score for a candidate that has already passed `match?`. Higher is a
    # better match.
    def score(needle, haystack)
      if needle.empty? || haystack.empty?
        SCORE_MIN
      elsif needle.length == haystack.length
        # `match?` has already passed, so equal lengths mean the strings are
        # equal (the caller has case-folded both when the search is
        # case-insensitive).
        SCORE_MAX
      elsif haystack.length > MAX_HAYSTACK
        SCORE_MIN
      else
        best_scores(needle, haystack).last.last
      end
    end

    private

      # The recurrence. `d[i][j]` is the best score for a match of the first
      # i+1 needle characters that *ends* on haystack[j]; `best[i][j]` is the
      # best score reachable at that position either way. Only `best` is handed
      # back — `d` exists to carry the consecutive-match bonus forward.
      def best_scores(needle, haystack)
        bonus = precompute_bonus(haystack)
        d = Array.new(needle.length) { Array.new(haystack.length, SCORE_MIN) }
        best = Array.new(needle.length) { Array.new(haystack.length, SCORE_MIN) }

        needle.each_char.with_index do |needle_char, i|
          prev_score = SCORE_MIN
          gap_score = SCORE_GAP_INNER
          if i == needle.length - 1
            gap_score = SCORE_GAP_TRAILING
          end

          haystack.each_char.with_index do |haystack_char, j|
            if needle_char == haystack_char
              d[i][j] = match_score(
                d,
                best,
                bonus,
                i,
                j,
              )
              prev_score = [d[i][j], prev_score + gap_score].max
            else
              d[i][j] = SCORE_MIN
              prev_score += gap_score
            end
            best[i][j] = prev_score
          end
        end

        best
      end

      def match_score(d, best, bonus, i, j)
        if i.zero?
          j * SCORE_GAP_LEADING + bonus[j]
        elsif j.zero?
          SCORE_MIN
        else
          [
            best[i - 1][j - 1] + bonus[j],
            # A consecutive match does not stack with the position bonus.
            d[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE,
          ].max
        end
      end

      # Which positions begin a word. The notional character before the string
      # is a "/", so the first character always gets the slash bonus.
      def precompute_bonus(haystack)
        previous = '/'
        haystack.each_char.map do |char|
          bonus_for(previous, char).tap { previous = char }
        end
      end

      def bonus_for(previous, char)
        case previous
        when '/' then SCORE_MATCH_SLASH
        when '-', '_', ' ' then SCORE_MATCH_WORD
        when '.' then SCORE_MATCH_DOT
        else
          if lower?(previous) && upper?(char)
            SCORE_MATCH_CAPITAL
          else
            0
          end
        end
      end

      def lower?(char) = char.downcase == char
      def upper?(char) = char.upcase == char
  end
end
