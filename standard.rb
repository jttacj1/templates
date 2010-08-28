application_name = ask('What is the application name?')

plugin "mobile_fu", :git => "git://github.com/brendanlim/mobile-fu.git -r 2.x"
plugin "time_travel", :git => "git://github.com/notahat/time_travel.git"
gem "devise", :version => '1.0.8'
gem "rack", :version => '1.1.0'
gem "inherited_resources", :version => '1.0.6'
rake "gems:unpack"
rake "rails:freeze:gems"
generate :rspec
generate :cucumber, '--rspec --webrat'
generate :pickle
generate :devise, 'User'
generate :devise_views

file 'features/support/time_travel.rb', <<-END_TIME_TRAVEL
require "time_travel"
END_TIME_TRAVEL

file 'features/support/factory_girl.rb', <<-END_FACTORY_GIRL
require "factory_girl"
require File.dirname(__FILE__) + "/../../spec/factories"
END_FACTORY_GIRL
file "features/step_definitions/#{application_name}_steps.rb", <<-END_STEP_DEFINITIONS
Given /^I am using the "(.*)" browser$/ do |browser|
  header("User-Agent",browser)
  visit new_user_session_path
  fill_in("Email", :with => "test@example.com")
  fill_in("Password", :with => "secret")
  click_button("Sign in")
end

Given /^I am an anonymous user using the "(.*)" browser$/ do |browser|
  header("User-Agent",browser)
end
END_STEP_DEFINITIONS

file "spec/factories.rb", <<-END_FACTORIES
Factory.define :user do |f|
  f.email 'test@example.com'
  f.password 'secret'
end
END_FACTORIES

# Create default stylesheets
file "public/stylesheets/#{application_name}.css", <<-END_CSS
body {
  margin: 0;
  font-family: arial,sans-serif;
}

\##{application_name}-body {
  padding: 3px 8px 0;
  float: left;
}

\##{application_name}-head {
  border-bottom: 1px solid #C9D7F1;
  padding: 3px 8px 0;
  font-size: 13px;
  height: 20px;
}

\##{application_name}-context-menu {
  float: right;
  width: 200px;
}

\##{application_name}-navigation-menu {
  float: left;
}

\##{application_name}-user-menu {
  text-align: right;
}
END_CSS

file "public/stylesheets/#{application_name}-mobile.css", <<-END_CSS_MOBILE
body {
  font-family: arial,sans-serif;
}

\##{application_name}-body {
}

\##{application_name}-foot {
  border-top: 1px solid #C9D7F1;
  font-size: 13px;
}

\##{application_name}-navigation-menu {
}

\##{application_name}-user-menu {
}
END_CSS_MOBILE

# Configure Application Controller
app_controller_additions =<<END_APP_CONTROLLER_ADDITIONS


  before_filter :authenticate_the_user
  before_filter :nonav

  has_mobile_fu

  private

  def rescue_action(e)
    if e.is_a? ActiveRecord::RecordNotFound
      render :file => "\#{RAILS_ROOT}/public/404.html",
             :status => '404 Not Found'
    else
      super
    end
  end

  def nonav
    @nonav = true if self.action_name == 'new'
    @nonav = true if self.action_name == 'create'
    @nonav = true if self.action_name == 'edit'
    @nonav = true if self.action_name == 'update'
    # @nonav = true unless user_signed_in?
  end

  def authenticate_the_user
    redirect_to(new_user_session_path(:unauthenticated => true)) unless user_signed_in? or
    # redirect_to (stored_location_for(:user) || root_path) unless user_signed_in? or
            self.class.to_s == "SessionsController" or
            self.class.to_s == "RegistrationsController" or
            self.class.to_s == "PasswordsController"
  end  


END_APP_CONTROLLER_ADDITIONS

gsub_file 'app/controllers/application_controller.rb', /(.*filter_parameter_logging.*)/, app_controller_additions

# Configure application layouts
file "app/views/layouts/application.html.erb", <<-END_APPLICATION_HTML_ERB
<html>
<head>
  <title><%= @page_title ? "\#{@page_title} - #{application_name.upcase}" : "#{application_name.upcase}" %></title>
  <%= stylesheet_link_tag '#{application_name}.css' %>
</head>
<body>
<% if @nonav.nil? %>
  <div id="#{application_name}-head">
    <div id="#{application_name}-navigation-menu">
      <%= link_to("MenuItem1", '#') %>
      <%= link_to("MenuItem2", '#') %>
    </div>
    <div id="#{application_name}-user-menu">
      <%= link_to("UserMenuItem1", '#') %>
       | <%= link_to("Sign out", destroy_user_session_path) %>
    </div>
  </div>
<% end %>
<div id="#{application_name}-body">
  <%= flash_messages %>
  <%= yield %>
</div>
<div id="#{application_name}-context-menu">
  <%= yield :#{application_name}_context_menu %>
</div>
</body>
</html>
END_APPLICATION_HTML_ERB
file "app/views/layouts/application.mobile.erb", <<-END_APPLICATION_MOBILE_ERB
<html>
<head>
  <title><%= @page_title ? "\#{@page_title} - #{application_name.upcase}" : "#{application_name.upcase}" %></title>
  <%= stylesheet_link_tag '#{application_name}-mobile.css' %>
</head>
<body>
<div id="#{application_name}-body">
  <%= flash_messages %>
  <%= yield %>
</div>
<div id="#{application_name}-context-menu">
  <%= yield :#{application_name}_context_menu %>
</div>
<% if @nonav.nil? %>
  <div id="#{application_name}-foot">
    <div id="#{application_name}-navigation-menu">
      <%= link_to("MenuItem1", '#') %><br />
      <%= link_to("MenuItem2", '#') %>
    </div>
    <div id="#{application_name}-user-menu">
      <%= link_to("PersonalMenuItem1", '#') %> <br />
      <%= link_to("Sign out", destroy_user_session_path) %>
    </div>
  </div>
<% end %>
</body>
</html>
END_APPLICATION_MOBILE_ERB


# Configure application helper
file "app/helpers/application_helper.rb", <<-END_APPLICATION_HELPER
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def flash_messages
    [:notice, :error].collect {|type| content_tag('div', flash[type], :id => type) if flash[type] }
  end

end
END_APPLICATION_HELPER

initializer 'mime_types.rb','Mime::Type.register_alias "text/html", :mobile'
file 'config/initializers/inherited_resources.rb', <<-END_INHERITED_RESOURCES_INITIALIZER
InheritedResources::BaseHelpers.class_eval do
  
  def begin_of_association_chain
    current_user
  end

end

InheritedResources::Responder.class_eval do

  alias :to_mobile :to_html

end
END_INHERITED_RESOURCES_INITIALIZER

git :init
git :add => "."
git :commit => "-a -m 'Initial Commit'"
