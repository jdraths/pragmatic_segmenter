# -*- encoding : utf-8 -*-
require 'pragmatic_segmenter/punctuation_replacer'
require 'pragmatic_segmenter/between_punctuation'


require 'pragmatic_segmenter/list'
require 'pragmatic_segmenter/abbreviation_replacer'
require 'pragmatic_segmenter/exclamation_words'

module PragmaticSegmenter
  # This class processing segmenting the text.
  class Processor

    attr_reader :text
    def initialize(language: Languages::Common)
      @language = language
    end

    # .process is run immediately after processor.new inside of the .segment command
    def process(text:)
      # The following rules are simply REGEX replacements to reformat your text string
      ## List searches for a list within a string and adds newlines before each list item.
      ## see PragmaticSegmenter::List for more...
      @text = List.new(text: text).add_line_break
      replace_abbreviations
      replace_numbers
      replace_continuous_punctuation
      @text.apply(@language::Abbreviations::WithMultiplePeriodsAndEmailRule)
      @text.apply(@language::GeoLocationRule)
      
      # This where the segmenting occurs
      split_into_segments
    end

    private

    def split_into_segments
      # the order we check these segments would be critical
      check_for_parens_between_quotes(@text).split("\r")
         .map! { |segment| segment.apply(@language::SingleNewLineRule, @language::EllipsisRules::All) }
         .map { |segment| check_for_punctuation(segment) }.flatten
         .map! { |segment| segment.apply(@language::SubSymbolsRules::All) }
         .map { |segment| post_process_segments(segment) }
         .flatten.compact.delete_if(&:empty?)
         .map! { |segment| segment.apply(@language::SubSingleQuoteRule) }
    end

    def post_process_segments(txt)
      return txt if txt.length < 2 && txt =~ /\A[a-zA-Z]*\Z/
      return if consecutive_underscore?(txt) || txt.length < 2
      txt.apply(
        @language::ReinsertEllipsisRules::All,
        @language::ExtraWhiteSpaceRule
      )

      if txt =~ @language::QUOTATION_AT_END_OF_SENTENCE_REGEX
        txt.split(@language::SPLIT_SPACE_QUOTATION_AT_END_OF_SENTENCE_REGEX)
      else
        txt.tr("\n", '').strip
      end
    end

    def check_for_parens_between_quotes(txt)
      return txt unless txt =~ @language::PARENS_BETWEEN_DOUBLE_QUOTES_REGEX
      txt.gsub!(@language::PARENS_BETWEEN_DOUBLE_QUOTES_REGEX) do |match|
        match.gsub(/\s(?=\()/, "\r").gsub(/(?<=\))\s/, "\r")
      end
    end

    def replace_continuous_punctuation
      @text.gsub!(@language::CONTINUOUS_PUNCTUATION_REGEX) do |match|
        match.gsub(/!/, '&ᓴ&').gsub(/\?/, '&ᓷ&')
      end
    end

    def consecutive_underscore?(txt)
      # Rubular: http://rubular.com/r/fTF2Ff3WBL
      txt.gsub(/_{3,}/, '').length.eql?(0)
    end

    def check_for_punctuation(txt)
      if @language::Punctuations.any? { |p| txt.include?(p) }
        process_text(txt)
      else
        txt
      end
    end

    def process_text(txt)
      txt << 'ȸ' unless @language::Punctuations.any? { |p| txt[-1].include?(p) }
      ExclamationWords.apply_rules(txt)
      between_punctuation(txt)
      txt = txt.apply(
        @language::DoublePunctuationRules::All,
        @language::QuestionMarkInQuotationRule,
        @language::ExclamationPointRules::All
      )
      txt = List.new(text: txt).replace_parens
      sentence_boundary_punctuation(txt)
    end

    def replace_numbers
      # @text was redefined in replace_abbreviations
      # .apply is a method of the Text class
      # English::Numbers::All is a set of rules defined in Languages::Common
      @text.apply @language::Numbers::All
    end

    def abbreviations_replacer
      if defined? @language::AbbreviationReplacer
        @language::AbbreviationReplacer
      else
        AbbreviationReplacer
      end
    end

    def replace_abbreviations
      # AbbreviationReplacer not a module of english, so use the root module
      @text = abbreviations_replacer.new(text: @text, language: @language).replace
    end

    def between_punctuation_processor
      if defined? @language::BetweenPunctuation
        @language::BetweenPunctuation
      else
        BetweenPunctuation
      end
    end

    def between_punctuation(txt)
      between_punctuation_processor.new(text: txt).replace
    end

    def sentence_boundary_punctuation(txt)
      txt = txt.apply @language::ReplaceColonBetweenNumbersRule if defined? @language::ReplaceColonBetweenNumbersRule
      txt = txt.apply @language::ReplaceNonSentenceBoundaryCommaRule if defined? @language::ReplaceNonSentenceBoundaryCommaRule

      txt.scan(@language::SENTENCE_BOUNDARY_REGEX)
    end
  end
end
