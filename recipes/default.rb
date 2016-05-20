include_recipe "homebrewalt::default"

if node['user'] && node['user']['id']
  user_name = node['user']['id']
  home_dir = Etc.getpwnam(user_name).dir
else
  user_name = node['current_user']
  home_dir = node['etc']['passwd'][user_name]['dir']
end

["homebrew.mxcl.postgresql.plist" ].each do |plist|
  plist_path = File.expand_path(plist, File.join(home_dir, 'Library', 'LaunchAgents'))
  if File.exists?(plist_path)
    log "postgresql plist found at #{plist_path}"
    execute "unload the plist (shuts down the daemon)" do
      command %'launchctl unload -w #{plist_path}'
      user user_name
    end
  else
    log "Did not find plist at #{plist_path} don't try to unload it"
  end
end

[ "/Users/#{user_name}/Library/LaunchAgents" ].each do |dir|
  directory dir do
    owner user_name
    action :create
  end
end

package "homebrew/postgres" do
  action [:install, :upgrade]
end

execute "copy over the plist" do
    command %'cp /usr/local/opt/postgresql/homebrew.mxcl.postgresql.plist ~/Library/LaunchAgents/'
    user user_name
end

execute "start the daemon" do
  command %'launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist'
  user user_name
end

ruby_block "Checking that postgres is running" do
  block do
    Timeout::timeout(60) do
      until File.exists?("/usr/local/var/postgres/postmaster.pid")
        sleep 1
      end
    end
  end
end

[ node['postgres_users'] ].flatten.compact.each do |postgres_user|
  execute "Creating postgres user: #{postgres_user}" do
    command "createuser -s #{postgres_user}"
    user user_name
    not_if { system("psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='#{postgres_user}'\" | grep -q 1") }
  end
end
