# Supermail

Organize emails with plain 'ol Ruby objects in a Rails application:

```ruby
class User::WelcomeEmail < ApplicationEmail
  def initialize(user:)
    @user = user
  end

  def to = @user.email
  def subject = "Welcome to Beautiful Ruby"
  
  def plain = <<~TEXT
    Hi #{@user.name},

    You're going to learn a ton at https://beautifulruby.com.
  TEXT

  def html = safe <<~HTML
    <h1>Hi #{@user.name},</h1>
    <p>You're going to learn a ton at <a href="https://beautifulruby.com">Beautiful Ruby</a>.</p>
  HTML
end
```

Or use ERB templates like Rails:

```ruby
# app/emails/welcome_email.rb
class WelcomeEmail < ApplicationEmail
  include Supermail::Rails::Rendering
  
  def initialize(user:)
    @user = user
  end

  def to = @user.email
  def subject = "Welcome!"
  # Templates automatically resolved from app/emails/welcome_email.html.erb and .text.erb
end
```

```erb
<!-- app/emails/welcome_email.html.erb -->
<h1>Hi <%= @user.name %>,</h1>
<p>Welcome to the app!</p>
```

Contrast that with Rails ActionMailer, where you will spend 20 minutes trying to figure out how to send an email. I created this gem because I got tired of digging through Rails docs to understand how to initialize an email and send it. PORO's FTW!

## Support this project

Learn how to build UI's out of Ruby classes and support this project by ordering the [Phlex on Rails video course](https://beautifulruby.com/phlex).

[![](https://immutable.terminalwire.com/hmM9jvv7yF89frBUfjikUfRmdUsTVZ8YvXc7OnnYoERXfLJLzDcj5dFM7qdfMG2bqQLuw633Zt1gl3O7z0zKmH6k8QmifN7z0kJo.png)](https://beautifulruby.com/phlex/forms/introduction)


## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add supermail
```

Then install it in Rails.

```bash
rails generate supermail:install
```

This creates the `ApplicationEmail` class at `app/emails/application_email.rb`.

## Usage

### Basic emails

Define emails by overriding `to`, `from`, `subject`, `plain`, and `html` methods:

```ruby
class WelcomeEmail < ApplicationEmail
  def initialize(user:)
    @user = user
  end

  def to = @user.email
  def subject = "Welcome!"
  def plain = "Welcome to the app, #{@user.name}!"
  def html = safe "<h1>Welcome to the app, #{@user.name}!</h1>"
end
```

- If both `plain` and `html` are defined, a multipart email is sent
- If only `plain` is defined, a text-only email is sent
- If only `html` is defined, an HTML-only email is sent

### Wrapping content with hooks

Use `before_*` and `after_*` hooks in your base class to wrap all emails:

```ruby
class ApplicationEmail < Supermail::Rails::Base
  def from = "website@example.com"

  def before_html = "<html><body>"
  def after_html = <<~HTML
    <p>Best,<br>The Example.com Team</p>
    </body></html>
  HTML

  def after_plain = <<~TEXT

    Best,
    The Example.com Team
  TEXT
end
```

Child emails just define their content - the hooks handle the wrapping:

```ruby
class WelcomeEmail < ApplicationEmail
  def subject = "Welcome!"
  def plain = "Welcome to the app!"
  def html = safe "<h1>Welcome!</h1>"
end
```

### Using Phlex components

Return any object that responds to `#call` from `html`:

```ruby
class WelcomeEmail < ApplicationEmail
  def html = WelcomeEmailView.new(user: @user)
end
```

### CSS inlining

Override `html_body` for post-processing like CSS inlining:

```ruby
class ApplicationEmail < Supermail::Rails::Base
  protected

  def html_body
    content = super
    return nil unless content
    Premailer.new(content, with_html_string: true).to_inline_css
  end
end
```

### Send emails

```ruby
WelcomeEmail.new(user: User.first).deliver_now
WelcomeEmail.new(user: User.first).deliver_later
```

### Generate mailto: links

```erb
<%= link_to "Contact Support", SupportEmail.new(user: current_user).mailto %>
```

## Generators

Generate a new email:

```bash
rails generate supermail:email User::Welcome
```

Creates `app/emails/user/welcome_email.rb`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubymonolith/supermail.
