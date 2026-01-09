# frozen_string_literal: true

require "spec_helper"
require "generators/supermail/email/email_generator"

RSpec.describe Supermail::EmailGenerator, type: :generator do
  tests Supermail::EmailGenerator

  EMAIL_DESTINATION_PATH = Pathname.new(__dir__).join("../../tmp/generators")
  destination EMAIL_DESTINATION_PATH.to_s

  before { prepare_destination }
  after { FileUtils.rm_rf(EMAIL_DESTINATION_PATH) }

  describe "with namespaced email" do
    before { run_generator ["User::Welcome"] }

    describe "app/emails/user/welcome_email.rb" do
      subject { File.read(EMAIL_DESTINATION_PATH.join("app/emails/user/welcome_email.rb")) }
      it { is_expected.to match(/class User::WelcomeEmail < ApplicationEmail/) }
      it { is_expected.to match(/def plain = <<~TEXT/) }
      it { is_expected.to match(/def html = <<~HTML/) }
    end
  end

  describe "with simple email" do
    before { run_generator ["Welcome"] }

    describe "app/emails/welcome_email.rb" do
      subject { File.read(EMAIL_DESTINATION_PATH.join("app/emails/welcome_email.rb")) }
      it { is_expected.to match(/class WelcomeEmail < ApplicationEmail/) }
      it { is_expected.to match(/def plain = <<~TEXT/) }
      it { is_expected.to match(/def html = <<~HTML/) }
    end
  end

  describe "with email suffix provided" do
    before { run_generator ["WelcomeEmail"] }

    describe "app/emails/welcome_email.rb" do
      subject { File.read(EMAIL_DESTINATION_PATH.join("app/emails/welcome_email.rb")) }
      it { is_expected.to match(/class WelcomeEmail < ApplicationEmail/) }
      it { is_expected.not_to match(/WelcomeEmailEmail/) }
    end
  end
end
