def workspace_dir
  File.expand_path(File.dirname(__FILE__) + '/..')
end

def iris_dir
  File.expand_path("#{workspace_dir}/../../iris/trunk")
end

def is_postgres?
  ENV['DB_TYPE'] == 'postgres'
end

def is_mssql?
  ENV['DB_TYPE'].nil? || ENV['DB_TYPE'] == 'mssql'
end

# TODO: Remove this cruft once dbt is AR free
$LOAD_PATH.insert(0, "#{iris_dir}/vendor/rails-2.2.2/activesupport/lib")
$LOAD_PATH.insert(0, "#{iris_dir}/vendor/rails-2.2.2/activerecord/lib")
$LOAD_PATH.insert(0, "#{iris_dir}/vendor/gems/activerecord-jdbc-adapter-1.0.0/lib")

$LOAD_PATH.insert(0, "#{workspace_dir}/../dbt/lib")

require 'db_tasks'

DbTasks::Config.environment = ENV['DB_ENV'] if ENV['DB_ENV']
DbTasks::Config.log_filename = "#{workspace_dir}/target/dbt/logs/db.log"
DbTasks.add_database_driver_hook { db_driver_setup }

if is_postgres?
  DbTasks::Config.driver = 'Postgres'
  DbTasks::Config.config_filename = File.expand_path("#{workspace_dir}/config/pg_database.yml")
elsif is_mssql?
  DbTasks::Config.driver = 'Mssql'
  DbTasks::Config.config_filename = File.expand_path("#{workspace_dir}/config/mssql_database.yml")
else
  raise "Unknown DB_TYPE = #{ENV['DB_TYPE']}"
end

def define_dbt_tasks(project)
  DbTasks.add_database(:default,
                       :imports => {:default => {}},
                       :backup => true,
                       :restore => true) do |database|
    database.version = project.version
    generated_dir = "#{workspace_dir}/databases/generated"
    database.search_dirs = [generated_dir, "#{workspace_dir}/databases"]
    database.enable_domgen(:Footprints, 'domgen:load', 'domgen:sql')
    database.add_import_assert_filters
    database.enable_separate_import_task = true
    #database.enable_db_doc(generated_dir)
  end
end

def db_driver_setup
  load_jtds
  db_date_setup
end

def load_jtds
  if is_postgres?
    require File.expand_path("#{iris_dir}/../../Program Files (x86)/PostgreSQL/pgJDBC/postgresql-8.4-702.jdbc4.jar")
  else
    require File.expand_path("#{iris_dir}/vendor/jars/repository/net/sourceforge/jtds/jtds/1.2.4/jtds-1.2.4.jar")
  end
end

def db_date_setup
  require 'activerecord'

  ::ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS[:default] = '%d %b %Y'
  ::ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS[:default] = '%d %b %Y'

  # Futz with date formats to ensure that we don't get month/day mixup
  ::ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS.merge!(:db => '%d %b %Y')
  ::ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(:db => '%d %b %Y %H:%M:%S')
end
