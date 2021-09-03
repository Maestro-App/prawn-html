# frozen_string_literal: true

module PrawnHtml
  class DocumentRenderer
    NEW_LINE = { text: "\n" }.freeze
    SPACE = { text: ' ' }.freeze

    # Init the DocumentRenderer
    #
    # @param pdf [PdfWrapper] target PDF wrapper
    def initialize(pdf)
      @buffer = []
      @context = Context.new
      @pdf = pdf
    end

    # On tag close callback
    #
    # @param element [Tag] closing element wrapper
    def on_tag_close(element)
      render_if_needed(element)
      apply_tag_close_styles(element)
      context.last_text_node = false
      context.pop
    end

    # On tag open callback
    #
    # @param tag_name [String] the tag name of the opening element
    # @param attributes [Hash] an hash of the element attributes
    # @param element_styles [String] document styles to apply to the element
    #
    # @return [Tag] the opening element wrapper
    def on_tag_open(tag_name, attributes:, element_styles: '')
      tag_class = Tag.class_for(tag_name)
      return unless tag_class

      tag_class.new(tag_name, attributes: attributes, element_styles: element_styles).tap do |element|
        setup_element(element)
      end
    end

    # On text node callback
    #
    # @param content [String] the text node content
    #
    # @return [NilClass] nil value (=> no element)
    def on_text_node(content)
      return if content.match?(/\A\s*\Z/)

      buffer << context.text_node_styles.merge(text: prepare_text(content))
      context.last_text_node = true
      nil
    end

    # Render the buffer content to the PDF document
    def render
      return if buffer.empty?

      output_content(buffer.dup, context.block_styles)
      buffer.clear
      context.last_margin = 0
    end

    alias_method :flush, :render

    private

    attr_reader :buffer, :context, :pdf

    def setup_element(element)
      add_space_if_needed unless render_if_needed(element)
      apply_tag_open_styles(element)
      context.add(element)
      element.custom_render(pdf, context) if element.respond_to?(:custom_render)
    end

    def add_space_if_needed
      buffer << SPACE if buffer.any? && !context.last_text_node && ![NEW_LINE, SPACE].include?(buffer.last)
    end

    def render_if_needed(element)
      render_needed = element&.block? && buffer.any? && buffer.last != NEW_LINE
      return false unless render_needed

      render
      true
    end

    def apply_tag_close_styles(element)
      tag_styles = element.tag_close_styles
      context.last_margin = tag_styles[:margin_bottom].to_f
      pdf.advance_cursor(context.last_margin + tag_styles[:padding_bottom].to_f)
      pdf.start_new_page if tag_styles[:break_after]
    end

    def apply_tag_open_styles(element)
      tag_styles = element.tag_open_styles
      move_down = (tag_styles[:margin_top].to_f - context.last_margin) + tag_styles[:padding_top].to_f
      pdf.advance_cursor(move_down) if move_down > 0
      pdf.start_new_page if tag_styles[:break_before]
    end

    def prepare_text(content)
      white_space_pre = context.last && context.last.styles[:white_space] == :pre
      text = ::Oga::HTML::Entities.decode(context.before_content)
      text += white_space_pre ? content : content.gsub(/\A\s*\n\s*|\s*\n\s*\Z/, '').delete("\n").squeeze(' ')
      text
    end

    def output_content(buffer, block_styles)
      apply_callbacks(buffer)
      left_indent = block_styles[:margin_left].to_f + block_styles[:padding_left].to_f
      options = block_styles.slice(:align, :leading, :mode, :padding_left)
      options[:indent_paragraphs] = left_indent if left_indent > 0
      pdf.puts(buffer, options, bounding_box: bounds(block_styles))
    end

    def apply_callbacks(buffer)
      buffer.select { |item| item[:callback] }.each do |item|
        callback = Tag::CALLBACKS[item[:callback]]
        item[:callback] = callback.new(pdf, item)
      end
    end

    def bounds(block_styles)
      return unless block_styles[:position] == :absolute

      y = pdf.bounds.height - (block_styles[:top] || 0)
      w = pdf.bounds.width - (block_styles[:left] || 0)
      [[block_styles[:left] || 0, y], { width: w }]
    end
  end
end
