require 'erb'
require 'json'
require 'simple/console'

class ChefBuilder < Jenkins::Tasks::Builder

    attr_accessor :enabled, :dry_run, :chef_json_template, :color_output
    attr_accessor :ssh_host, :ssh_login, :ssh_identity_path, :chef_client_config

    display_name "Run chef client on remote host"

    def initialize(attrs = {})
        @enabled = attrs["enabled"]
        @dry_run = attrs["dry_run"]
        @chef_json_template = attrs["chef_json_template"]
        @ssh_host = attrs["ssh_host"]
        @ssh_login = attrs["ssh_login"]
        @chef_client_config = attrs["chef_client_config"]
        @color_output = attrs['color_output']
        @ssh_identity_path = attrs['ssh_identity_path']
    end

    def prebuild(build, listener)
    end

    def perform(build, launcher, listener)


        if @enabled == true
            @sc = Simple::Console.new(:color_output => @color_output)

            # generate chef json file


            env = build.native.getEnvironment()
            job = build.send(:native).get_project.name
            workspace = build.send(:native).workspace.to_s

            listener.info @sc.info('rendering ERB template')

            renderer = ERB.new(@chef_json_template)
            json_str = renderer.result
            json_str.sub! '"{','{'
            json_str.sub! '}"','}'

            listener.info @sc.info('parsing JSON string')

            JSON.parse(json_str)

            listener.info @sc.info('saving JSON to file')

            File.open("#{workspace}/chef.json", 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(json_str))) }

            chef_json_url = "#{env['JENKINS_URL']}/job/#{job}/ws/chef.json"

            listener.info @sc.info(chef_json_url, :title => 'chef json url')

            why_run_flag = ''
            if @dry_run == true 
                listener.info @sc.info('dry run mode is ON, so will run chef-client with --why-run flag')
                why_run_flag = '--why-run'
            end

            chef_color_flag = ''
            if @color_output == true 
                chef_color_flag = '--color'
            end

            listener.info @sc.info(@ssh_host, :title => 'host')
            cmd = []
            cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
            config_path = ''
            config_path = " -c #{@chef_client_config}" unless (@chef_client_config.nil? ||  @chef_client_config.empty?)

            ssh_command = 'ssh'

            unless ( @ssh_identity_path.nil? || @ssh_identity_path.empty? )
                ssh_command << " -i #{@ssh_identity_path}"
            end

            cmd << "#{ssh_command} #{@ssh_login}@#{@ssh_host} sudo chef-client -l info -j #{chef_json_url} #{config_path} #{why_run_flag} #{chef_color_flag}"
            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

    
        end


    end

end


