# frozen_string_literal: true

require "spec_helper"

# Plain text only email
class PlainOnlyEmail < Supermail::Rails::Base
  def initialize(to:, from:, subject:, content:, cc: [], bcc: [])
    @to = to
    @from = from
    @subject = subject
    @content = content
    @cc = cc
    @bcc = bcc
  end

  attr_reader :to, :from, :subject, :cc, :bcc

  def plain = @content
end

# HTML only email
class HtmlOnlyEmail < Supermail::Rails::Base
  def initialize(to:, from:, subject:, content:)
    @to = to
    @from = from
    @subject = subject
    @content = content
  end

  attr_reader :to, :from, :subject

  def html = safe @content
end

# Multipart email (both plain and HTML)
class MultipartEmail < Supermail::Rails::Base
  def initialize(to:, from:, subject:, plain_content:, html_content:)
    @to = to
    @from = from
    @subject = subject
    @plain_content = plain_content
    @html_content = html_content
  end

  attr_reader :to, :from, :subject

  def plain = @plain_content
  def html = safe @html_content
end

# Email with hooks
class EmailWithHooks < Supermail::Rails::Base
  def initialize(to:, from:, subject:, content:)
    @to = to
    @from = from
    @subject = subject
    @content = content
  end

  attr_reader :to, :from, :subject

  def plain = @content
  def html = safe @content

  def before_plain = "=== HEADER ===\n"
  def after_plain = "\n=== FOOTER ==="

  def before_html = "<html><body>"
  def after_html = "</body></html>"
end

# Email with callable renderer (like Phlex)
class CallableRenderer
  def initialize(content)
    @content = content
  end

  def call
    "<div>#{@content}</div>".html_safe
  end
end

class EmailWithCallable < Supermail::Rails::Base
  def initialize(to:, from:, subject:, content:)
    @to = to
    @from = from
    @subject = subject
    @content = content
  end

  attr_reader :to, :from, :subject

  def html = CallableRenderer.new(@content)
end

RSpec.describe "Plain text only email" do
  let(:email) { PlainOnlyEmail.new(
    to: "user@example.com",
    from: "support@example.com",
    subject: "Hello",
    content: "Hi there",
    cc: ["cc@example.com"],
    bcc: ["bcc@example.com"])
  }
  let(:message) { email.message }

  it "builds a Mail::Message" do
    expect(message).to be_a(Mail::Message)
  end

  it "sets the to header" do
    expect(message.to).to eq(["user@example.com"])
  end

  it "sets the from header" do
    expect(message.from).to eq(["support@example.com"])
  end

  it "sets the subject header" do
    expect(message.subject).to eq("Hello")
  end

  it "sets the body as plain text" do
    expect(message.body.to_s).to eq("Hi there")
  end

  it "sets content type to text/plain" do
    expect(message.content_type).to include("text/plain")
  end

  describe "#mailto" do
    it "passes all mail fields to the mailto URL" do
      result = email.mailto
      expect(result).to start_with("mailto:user@example.com?")
      expect(result).to include("from=support%40example.com")
      expect(result).to include("subject=Hello")
      expect(result).to include("body=Hi%20there")
    end
  end

  describe "delivery" do
    before do
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.deliveries.clear
      ActiveJob::Base.queue_adapter = :test
    end

    describe "#deliver_now" do
      it "delivers the email through ActionMailer" do
        expect {
          email.deliver_now
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    describe "#deliver" do
      it "delivers the email through ActionMailer" do
        expect {
          email.deliver
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    describe "#deliver_later" do
      it "enqueues the email for delivery through ActiveJob" do
        expect {
          email.deliver_later
        }.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(1)
      end
    end
  end
end

RSpec.describe "HTML only email" do
  let(:email) { HtmlOnlyEmail.new(
    to: "user@example.com",
    from: "support@example.com",
    subject: "Hello",
    content: "<h1>Hi there</h1>")
  }
  let(:message) { email.message }

  it "sets the body as HTML" do
    expect(message.body.to_s).to eq("<h1>Hi there</h1>")
  end

  it "sets content type to text/html" do
    expect(message.content_type).to include("text/html")
  end
end

RSpec.describe "Multipart email" do
  let(:email) { MultipartEmail.new(
    to: "user@example.com",
    from: "support@example.com",
    subject: "Hello",
    plain_content: "Hi there",
    html_content: "<h1>Hi there</h1>")
  }
  let(:message) { email.message }

  it "creates a multipart message" do
    expect(message.content_type).to include("multipart/alternative")
  end

  it "has two parts" do
    expect(message.parts.size).to eq(2)
  end

  it "has a text/plain part" do
    text_part = message.parts.find { |p| p.content_type.include?("text/plain") }
    expect(text_part).not_to be_nil
    expect(text_part.body.to_s).to eq("Hi there")
  end

  it "has a text/html part" do
    html_part = message.parts.find { |p| p.content_type.include?("text/html") }
    expect(html_part).not_to be_nil
    expect(html_part.body.to_s).to eq("<h1>Hi there</h1>")
  end
end

RSpec.describe "Email with hooks" do
  let(:email) { EmailWithHooks.new(
    to: "user@example.com",
    from: "support@example.com",
    subject: "Hello",
    content: "Main content")
  }
  let(:message) { email.message }

  it "wraps plain content with before/after hooks" do
    text_part = message.parts.find { |p| p.content_type.include?("text/plain") }
    expect(text_part.body.to_s).to eq("=== HEADER ===\nMain content\n=== FOOTER ===")
  end

  it "wraps html content with before/after hooks" do
    html_part = message.parts.find { |p| p.content_type.include?("text/html") }
    expect(html_part.body.to_s).to eq("<html><body>Main content</body></html>")
  end
end

RSpec.describe "Email with callable renderer" do
  let(:email) { EmailWithCallable.new(
    to: "user@example.com",
    from: "support@example.com",
    subject: "Hello",
    content: "Rendered content")
  }
  let(:message) { email.message }

  it "calls the renderer to get HTML content" do
    expect(message.body.to_s).to eq("<div>Rendered content</div>")
  end

  it "sets content type to text/html" do
    expect(message.content_type).to include("text/html")
  end
end
