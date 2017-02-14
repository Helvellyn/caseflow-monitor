class MonitorJob < ActiveJob::Base
  queue_as :default

  def initialize
    super
    @worker = {}
  end

  def perform()

    begin
      # setup all the services that need to be monitored
      monitor_services = setup_services

      # Register all services into a global array. This array is expected to be
      # read only, and is thread-safe for updates.
      Rails.application.config.monitor_services = monitor_services

      # Spin up threads to monitor all the services
      monitor_services.each do |serviceClass|
        run_query(serviceClass)
      end

      puts "setting up zombie monitor"
      setup_zombie_monitor

    rescue Exception => e
      puts e.message
      puts e.backtrace
    end

  end

  def max_attempts
    1
  end

  def setup_services
    monitor_services = []
    if Rails.env.development?
      puts "loading up fake services\n\n\n\n"
      if Fakes::BGSService.prevalidate
        monitor_services.push(Fakes::BGSService)
      end
      if Fakes::VacolsService.prevalidate
        monitor_services.push(Fakes::VacolsService)
      end
      if Fakes::VBMSService.prevalidate
        monitor_services.push(Fakes::VBMSService)
      end

    else
      puts "loading up production services\n\n\n\n"
      if BGSService.prevalidate
       # monitor_services.push(BGSService)
      end

      if VacolsService.prevalidate
        #monitor_services.push(VacolsService)
      end

      if VBMSService.prevalidate
        monitor_services.push(VBMSService)
      end
    end
    monitor_services
  end

  def run_query(serviceClass)
    th = Thread.new do
      while 1 do
        begin
          service = serviceClass.new
          puts "#{service.name} query started"
          @worker[serviceClass.service_name.to_sym] = {
            :thread => th,
            :service => service,
            :serviceClass => serviceClass
          }
          service.query
          puts "#{service.name} query done"
        rescue Exception => e
          service.save
          puts "run_query failed\n\n\n\n"
          puts e.message
          puts e.backtrace
        end
        sleep 1
      end
    end
  end

  def setup_zombie_monitor
    puts "setting up zombie monitor"
    Thread.new do
      puts "running zombie monitor thread"
      loop do
        sleep 60
        begin
          puts "in loop"
          @worker.each do |service_name, worker_data|
            puts "in worker loop"
            duration = Time.now - worker_data[:service].time
            puts "duration for #{worker_data[:service]} is #{duration}"
            if duration > 30
              puts "Zombie detected, killing thread and restarting #{worker_data[:thread]}"
              worker_data[:thread].kill
              worker_data[:thread].join 1
              run_query(worker_data[:serviceClass])
            end
            puts "worker loop done"
          end
          puts "get here!!!!!!"
        rescue Exception => e
          puts "run_query failed\n\n\n\n"
          puts e.message
          puts e.backtrace
        end
        puts "would it get here????"
      end
    end
  end

end
