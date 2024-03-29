namespace :backup do

  namespace :db do

    # Get the build number by parsing the svn info data.
    # This function is inside the rake task so we can use it with sake
    def get_build_number
      begin
        f = File.open "#{Rails.root}/.svn/entries"
        # The revision information is on 4 lines in .svn/entries
        3.times {f.gets}
        f.gets.chomp
      rescue
        'x'
      end
    end
    
    # SVN  Build number
    BUILD_NUMBER = get_build_number
    
    desc 'Create YAML fixtures from your DB content'
    task :extract_content => :environment do
      sql  = "SELECT * FROM %s"
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
      ActiveRecord::Base.connection.tables.each do |table_name|
        i = "000"
        FileUtils.mkdir_p("#{Rails.root}/backup/#{Rails.env}/build_#{BUILD_NUMBER}/fixtures/") 

        File.open("#{Rails.root}/backup/#{Rails.env}/build_#{BUILD_NUMBER}/fixtures/#{table_name}.yml", 'w') do |file|
          data = ActiveRecord::Base.connection.select_all(sql % table_name)
          nb_record = data.size
          
          while i.to_i <  nb_record do
            file.write data[i.to_i, 100].inject({}) { |hash, record|
              hash["#{table_name}_#{i.succ!}"] = record
              hash
            }.to_yaml[5..-1]
            # Delete the "--- \n" part in top of all yaml return
          end
        end
      end
    end

      desc 'Dump the db schema'
      task :extract_schema => :environment do
        require 'active_record/schema_dumper'
        ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
        FileUtils.mkdir_p("#{Rails.root}/backup/#{Rails.env}/build_#{BUILD_NUMBER}/schema/") 
        File.open("#{Rails.root}/backup/#{Rails.env}/build_#{BUILD_NUMBER}/schema/schema.rb", "w") do |file|
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
        end
      end
      
      desc 'create a backup folder containing your db schema and content data (see backup/{env}/build_{build number})'
      task :dump => ['backup:db:extract_content', 'backup:db:extract_schema']
      
      desc 'load your backed up data from a previous build. rake backup:db:load BUILD=1182 or rake backup:db:load BUILD=1182 DUMP_ENV=production'
      task :load => :environment do
        @build     = ENV['BUILD'] || BUILD_NUMBER
        @env       = ENV['DUMP_ENV'] || Rails.env
        load("#{Rails.root}/backup/#{@env}/build_#{@build}/schema/schema.rb")

        require 'active_record/fixtures'
        Dir.glob(File.join(Rails.root, "backup/#{@env}/build_#{@build}/", 'fixtures', '*.yml')).each do |fixture_file|
          Fixtures.create_fixtures("#{Rails.root}/backup/#{@env}/build_#{@build}/fixtures", File.basename(fixture_file, '.yml'))
        end
      end

  end

end
