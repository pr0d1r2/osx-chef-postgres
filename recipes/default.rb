include_recipe "homebrewalt::default"

["homebrew.mxcl.postgresql.plist" ].each do |plist|
  plist_path = File.expand_path(plist, File.join('~', 'Library', 'LaunchAgents'))
  if File.exists?(plist_path)
    log "postgresql plist found at #{plist_path}"
    execute "unload the plist (shuts down the daemon)" do
      command %'launchctl unload -w #{plist_path}'
      user node['current_user']
    end
  else
    log "Did not find plist at #{plist_path} don't try to unload it"
  end
end

[ "/Users/#{node['current_user']}/Library/LaunchAgents" ].each do |dir|
  directory dir do
    owner node['current_user']
    action :create
  end
end

package "homebrew/postgres" do
  action [:install, :upgrade]
end

execute "copy over the plist" do
    command %'cp /usr/local/opt/postgresql/homebrew.mxcl.postgresql.plist ~/Library/LaunchAgents/'
    user node['current_user']
end

execute "start the daemon" do
  command %'launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist'
  user node['current_user']
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
    user node['current_user']
    not_if { system("psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='#{postgres_user}'\" | grep -q 1") }
  end
end
