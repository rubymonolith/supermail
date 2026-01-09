# frozen_string_literal: true

require_relative "supermail/version"
require "action_mailer"
require "erb"

module Supermail
  class Error < StandardError; end

  module Rails
    # This is a bizzare work around for a commit that broke https://github.com/rails/rails/commit/c594ba4ffdb016c7b2a22055f41dfb2c4409594d
    # further proving the bewildering maze of indirection in Rails ActionMailer.
    class Mailer < ActionMailer::Base
      def mail(...)
        super(...)
      end

      def multipart_mail(to:, from:, cc:, bcc:, subject:, text_body:, html_body:)
        mail(to:, from:, cc:, bcc:, subject:) do |format|
          format.text { render plain: text_body }
          format.html { render html: html_body.html_safe }
        end
      end

      def self.message_delivery(**)
        ActionMailer::MessageDelivery.new self, :mail, **
      end

      def self.multipart_message_delivery(**)
        ActionMailer::MessageDelivery.new self, :multipart_mail, **
      end
    end

    class Base
      delegate \
          :deliver,
          :deliver_now,
          :deliver_later,
          :message,
        to: :message_delivery

      def to = nil
      def from = nil
      def subject = nil
      def cc = []
      def bcc = []

      # Content methods - override in subclasses
      def plain = nil
      def html = nil

      # Hooks for wrapping content
      def before_plain = nil
      def after_plain = nil
      def before_html = nil
      def after_html = nil

      # Assemble parts with hooks
      def around_plain(content) = "#{before_plain}#{content}#{after_plain}"
      def around_html(content) = "#{before_html}#{content}#{after_html}"

      # Mark content as HTML safe
      def safe(content) = content.html_safe

      # Generate a mailto: URL with appropriate escaping.
      def mailto = MailTo.href(to:, from:, cc:, bcc:, subject:, body: plain)
      alias :mail_to :mailto

      protected

      # Final assembled content - override for advanced use cases (e.g., CSS inlining)
      def plain_body
        content = render_part(plain)
        return nil unless content
        around_plain(content)
      end

      def html_body
        content = render_part(html)
        return nil unless content
        around_html(content).html_safe
      end

      private

      def render_part(part)
        case part
        when nil then nil
        when String then part
        else part.call.to_s
        end
      end

      def message_delivery
        text_part = plain_body
        html_part = html_body

        if text_part && html_part
          Rails::Mailer.multipart_message_delivery(
            to:,
            from:,
            cc:,
            bcc:,
            subject:,
            text_body: text_part,
            html_body: html_part
          )
        elsif html_part
          Rails::Mailer.message_delivery(
            to:,
            from:,
            cc:,
            bcc:,
            subject:,
            content_type: "text/html",
            body: html_part
          )
        else
          Rails::Mailer.message_delivery(
            to:,
            from:,
            cc:,
            bcc:,
            subject:,
            body: text_part
          )
        end
      end
    end
  end

  module MailTo
    extend self

    def href(to:, **params)
      q = query(**params)
      q.empty? ? "mailto:#{to}" : "mailto:#{to}?#{q}"
    end

    def query(**params)
      params
        .compact                          # drop nils
        .reject { |k, v| v.is_a?(Array) && v.empty? }  # drop empty arrays
        .map { |k, v| "#{k}=#{mailto_escape(v)}" }
        .join("&")
    end

    private

    def mailto_escape(str)
      ERB::Util.url_encode(str.to_s).tr("+", "%20")
    end
  end
end
