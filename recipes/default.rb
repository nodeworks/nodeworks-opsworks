#
# Cookbook:: nodeworks_opsworks
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

command = search(:aws_opsworks_command).first
deploy_app = command[:args][:app_ids].first
app = search(:aws_opsworks_app, "app_id:#{deploy_app}").first
app_path = "/var/www/" + app[:shortname]

apt_update 'update'

# Install NGinx
package 'nginx' do
  not_if { File.exist?("/etc/init.d/nginx") }
end

# Setup the app directory
directory app_path do
  owner 'www-data'
  group 'www-data'
  mode '0755'
  recursive true
end

include_recipe 'certbot::install'

directory '/var/www/certbot' do
  owner 'www-data'
  group 'www-data'
  mode '0755'
  recursive true
end

certbot_certonly_webroot 'something' do
  webroot_path '/var/www/certbot'
  email 'rob@nodeworks.com'
  domains ['www.adaactionguide.org']
  agree_tos true
end

# Deploy git repo from opsworks app
application app_path do
  owner 'www-data'
  group 'www-data'

  git do
    user 'root'
    group 'root'
    repository app[:app_source][:url]
    deploy_key app[:app_source][:ssh_key]
  end

  execute "chown-data-www" do
    command "chown -R www-data:www-data #{app_path}"
    user "root"
    action :run
  end
end

# Setup the nginx config file for the site
template "/etc/nginx/sites-enabled/#{app[:shortname]}" do
  source "#{app[:environment][:APP_TYPE]}.erb"
  owner "root"
  group "root"
  mode 0644
  variables( :app => app )
end

# Reload nginx
service "nginx" do
  supports :status => true, :restart => true, :reload => true, :stop => true, :start => true
  action :reload
end

# Notify slack of a successful deployment
slack_notify "notify_deployment" do
  message "App #{app[:name]} deployed successfully"
  webhook_url 'https://hooks.slack.com/services/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'
end
