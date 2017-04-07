# -*- encoding : utf-8 -*-
require 'pragmatic_segmenter/languages'

module PragmaticSegmenter
  # This class segments a text into an array of sentences.
  class Segmenter
    attr_reader :text, :language, :doc_type

    def initialize(text:, language: 'en', doc_type: nil, clean: true)
      return unless text
      @language = language
      @language_module = Languages.get_language_by_code(language) # this results in a language (i.e. PragmaticSegmenter::Languages::English)
      @doc_type = doc_type

      if clean
        # cleaner (below) is defined as a class; .clean (for English) runs clean_quotations
        @text = cleaner.new(text: text, doc_type: @doc_type, language: @language_module).clean
      else
        @text = text
      end
    end

    # segment is the basic command run after PragmaticSegmenter.new(whatever)
    def segment
      return [] unless @text
      # processor is a class inside PragmaticSegmenter's root
      ## probably enabled as a module of Langauge:: because PragmaticSegmenter::Languages includes require 'pragmatic_segmenter/processor'
      processor.new(language: @language_module).process(text: @text)
    end

    private

    def processor
      @language_module::Processor
    rescue
      Processor
    end

    def cleaner
      @language_module::Cleaner
    rescue
      Cleaner
    end
  end
end
