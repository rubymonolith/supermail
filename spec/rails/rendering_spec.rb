# frozen_string_literal: true

require "spec_helper"
require "supermail/rails/rendering"

# Create test fixture directory
FIXTURE_PATH = Pathname.new(__dir__).join("../fixtures/emails")

# Email with implicit rendering (no plain/html defined)
class ImplicitEmail < Supermail::Rails::Base
  include Supermail::Rails::Rendering

  self.view_paths = [FIXTURE_PATH.to_s]

  def initialize(name:)
    @name = name
  end

  def to = "user@example.com"
  def from = "test@example.com"
  def subject = "Test"
end

# Email with explicit rendering
class ExplicitEmail < Supermail::Rails::Base
  include Supermail::Rails::Rendering

  self.view_paths = [FIXTURE_PATH.to_s]

  def initialize(name:)
    @name = name
  end

  def to = "user@example.com"
  def from = "test@example.com"
  def subject = "Test"

  def plain = render("explicit_email", formats: [:text])
  def html = render("explicit_email", formats: [:html])
end

# Email with layout
class LayoutEmail < Supermail::Rails::Base
  include Supermail::Rails::Rendering

  self.view_paths = [FIXTURE_PATH.to_s]
  self.layout = "email"

  def initialize(name:)
    @name = name
  end

  def to = "user@example.com"
  def from = "test@example.com"
  def subject = "Test"
end

# Email with only HTML template (no text)
class HtmlOnlyTemplateEmail < Supermail::Rails::Base
  include Supermail::Rails::Rendering

  self.view_paths = [FIXTURE_PATH.to_s]

  def to = "user@example.com"
  def from = "test@example.com"
  def subject = "Test"
end

RSpec.describe Supermail::Rails::Rendering do
  before(:all) do
    # Create fixture templates
    FileUtils.mkdir_p(FIXTURE_PATH.join("layouts"))
    
    File.write(FIXTURE_PATH.join("implicit_email.html.erb"), "<h1>Hello <%= @name %></h1>")
    File.write(FIXTURE_PATH.join("implicit_email.text.erb"), "Hello <%= @name %>")
    
    File.write(FIXTURE_PATH.join("explicit_email.html.erb"), "<p>Explicit: <%= @name %></p>")
    File.write(FIXTURE_PATH.join("explicit_email.text.erb"), "Explicit: <%= @name %>")
    
    File.write(FIXTURE_PATH.join("layout_email.html.erb"), "<div>Layout content</div>")
    File.write(FIXTURE_PATH.join("layout_email.text.erb"), "Layout content")
    
    File.write(FIXTURE_PATH.join("layouts/email.html.erb"), "<html><body><%= yield %></body></html>")
    File.write(FIXTURE_PATH.join("layouts/email.text.erb"), "=== EMAIL ===\n<%= yield %>\n=== END ===")
    
    File.write(FIXTURE_PATH.join("html_only_template_email.html.erb"), "<h1>HTML Only</h1>")
  end

  after(:all) do
    FileUtils.rm_rf(FIXTURE_PATH)
  end

  describe "implicit rendering" do
    let(:email) { ImplicitEmail.new(name: "World") }
    let(:message) { email.message }

    it "renders the HTML template based on class name" do
      html_part = message.parts.find { |p| p.content_type.include?("text/html") }
      expect(html_part.body.to_s).to eq("<h1>Hello World</h1>")
    end

    it "renders the text template based on class name" do
      text_part = message.parts.find { |p| p.content_type.include?("text/plain") }
      expect(text_part.body.to_s).to eq("Hello World")
    end

    it "creates a multipart message" do
      expect(message.content_type).to include("multipart/alternative")
    end
  end

  describe "explicit rendering" do
    let(:email) { ExplicitEmail.new(name: "Explicit") }
    let(:message) { email.message }

    it "renders the explicitly specified template" do
      html_part = message.parts.find { |p| p.content_type.include?("text/html") }
      expect(html_part.body.to_s).to eq("<p>Explicit: Explicit</p>")
    end
  end

  describe "layout rendering" do
    let(:email) { LayoutEmail.new(name: "Layout") }
    let(:message) { email.message }

    it "wraps content in the HTML layout" do
      html_part = message.parts.find { |p| p.content_type.include?("text/html") }
      expect(html_part.body.to_s).to eq("<html><body><div>Layout content</div></body></html>")
    end

    it "wraps content in the text layout" do
      text_part = message.parts.find { |p| p.content_type.include?("text/plain") }
      expect(text_part.body.to_s).to eq("=== EMAIL ===\nLayout content\n=== END ===")
    end
  end

  describe "partial template availability" do
    let(:email) { HtmlOnlyTemplateEmail.new }
    let(:message) { email.message }

    it "sends HTML-only when no text template exists" do
      expect(message.content_type).to include("text/html")
      expect(message.body.to_s).to eq("<h1>HTML Only</h1>")
    end
  end
end
