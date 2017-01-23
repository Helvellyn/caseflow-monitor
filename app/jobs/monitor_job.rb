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

      setup_zombie_monitor

    rescue Exception => e
      puts e.message
      puts exception.backtrace
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
        monitor_services.push(BGSService)
      end

      if VacolsService.prevalidate
        monitor_services.push(VacolsService)
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
          @worker[serviceClass.service_name.to_sym] = {
            :thread => th,
            :service => service,
            :serviceClass => serviceClass
          }
          service.query
        rescue Exception => e
          puts e.message
          puts exception.backtrace
        end
        sleep 300
      end
    end
  end

  def setup_zombie_monitor
    Thread.new do
      while 1 do
        @worker.each do |service_name, worker_data|
          duration = Time.now - worker_data[:service].time
          if duration > 300
            puts "Zombie detected, killing thread and restarting #{worker_data[:thread]}"
            worker_data[:thread].kill
            worker_data[:thread].join 1
            run_query(worker_data[:serviceClass])
          end
        end
        sleep 1
      end
    end
  end

end