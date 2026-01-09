# frozen_string_literal: true

require "action_view"

module Supermail
  module Rails
    module Rendering
      extend ActiveSupport::Concern

      included do
        class_attribute :view_paths, default: ["app/emails"]
        class_attribute :layout, default: nil
      end

      def render(template, layout: self.class.layout, formats: [:html], locals: {})
        view_context = build_view_context(formats)
        
        options = { template: template, locals: locals }
        options[:layout] = "layouts/#{layout}" if layout
        
        view_context.render(options)
      end

      protected

      # Override to support implicit template rendering
      def plain_body
        content = render_part(plain)
        content ||= render_implicit_template(:text)
        return nil unless content
        around_plain(content)
      end

      def html_body
        content = render_part(html)
        content ||= render_implicit_template(:html)
        return nil unless content
        around_html(content).html_safe
      end

      private

      def template_name
        self.class.name.underscore
      end

      def render_implicit_template(format)
        render(template_name, formats: [format])
      rescue ActionView::MissingTemplate
        nil
      end

      def build_view_context(formats)
        lookup_context = ActionView::LookupContext.new(self.class.view_paths)
        lookup_context.formats = formats

        view_class = ActionView::Base.with_empty_template_cache
        
        if defined?(::Rails.application) && ::Rails.application
          view_class.include ::Rails.application.routes.url_helpers
          view_class.include ::Rails.application.helpers if ::Rails.application.respond_to?(:helpers)
        end

        view_class.new(lookup_context, assigns_for_view, self)
      end

      def assigns_for_view
        instance_variables.each_with_object({}) do |ivar, hash|
          name = ivar.to_s.delete_prefix("@")
          next if name.start_with?("_")
          hash[name] = instance_variable_get(ivar)
        end
      end
    end
  end
end
