#!/usr/bin/ruby
require "highline/import"
require "colorize"

def service_request auto_log, evm_log, request_id
  task_id =  0
  service_tasks = []
=begin
  File.open(auto_log, "r") do |f|
    f.each_line do |line|
      if line.include?("service_template_provision_request_#{request_id}")
        if line.match?(/.*Updated\snamespace.*request=SERVICE_PROVISION_INFO.*/)
          task_id = line[/.*Updated\snamespace.*_provision_task=(.*)&User%3A.*/, 1]
        end
      end
    end
  end
=end
  File.open(evm_log, "r") do |f|
    f.each_line do |line|
      if line.include?("service_template_provision_request_#{request_id}")
        if line.match?(/.*create_child_task.*creating.*/)
          service_tasks.push(line[/TemplateProvisionTask:(.*)>\sw/, 1])
        end
      end
    end
  end
  return service_tasks
end

def the_real_deal auto_log, evm_log, service_tasks
  service_attributes = {}
  bundle = false
  service_tasks.each do |task_id|
    service_attributes[task_id] = {}
    service_attributes[task_id]["ERROR"] = []
  end
  service_tasks.each do |task_id|
    File.open(auto_log, "r") do |f|
      f.each_line do |line|
        if line.include?("service_template_provision_task_#{task_id}")
          if line.include?("Instantiating [/Service/Provisioning/StateMachines/ServiceProvision_Template/")
            type = line[/ServiceProvision_Template\/(.*)\?MiqServer/, 1]
            bundle = true if type.include?("Bundle")
            service_attributes[task_id]["type"] = type
          elsif line.include?("AEMethod groupsequencecheck")
            service_attributes[task_id]["service_id"] = line[/service_id:\s(.*)/, 1] if line.include?("service_id")
            service_attributes[task_id]["object_name"] = line[/object_name:\s(.*)/, 1] if line.include?("object_name")
            service_attributes[task_id]["request"] = line[/request:\s(.*)/, 1] if line.include?("request")
            service_attributes[task_id]["service_id"] = line[/service_id:\s(.*)/, 1] if line.include?("service_id")
          elsif line.include?("ERROR") || line.include?("WARN")
            service_attributes[task_id]["ERROR"].push(line)
          end
        end
      end
    end
    service_tasks.each do |task_id|
      service_attributes[task_id]["miq_requests"] = []
      File.open(evm_log, "r") do |f|
        f.each_line do |line|
          if line.include?("service_template_provision_task_#{task_id}")
            if service_attributes[task_id]["request"] == "clone_to_service"
              service_attributes[task_id]["miq_requests"].push(line[/object_id=>(.*),\s:attrs/, 1]) if line.include?("request\"=>\"vm_provision")
            end
          end
        end
      end
    end
  end

  service_attributes.each do |service_task, attributes|
    count = 0
    print "   Service Task: ".white + "#{service_task}".light_green + " and " + "Attributes".white + ": {"
    attributes.each do |k,v|
      print "\"" + "#{k}".white + "\"=>\"" + "#{v}".light_green + "\""
      count += 1
      if count < attributes.length 
        print ", "
      else
        puts "}"
      end      
    end
    puts
  end

#    bundle = service_tasks[0]["type"].include?("Bundle")
  return bundle
end

def service_task auto_log, evm_log, service_tasks, bundle
  miq_tasks = []
  #service_tasks = []
  service_states = {}
  custom_code = []
=begin
  File.open(evm_log, "r") do |f|
    f.each_line do |line|
      if line.include?("service_template_provision_task_#{task_id}")
        if line.match?(/.*MiqQueue.put.*clone_to_service.*/)
          temp = (line[/.*ServiceTemplateProvisionTask.*object_id=>(.*),\s:namespace.*/, 1])
          service_tasks.push(temp) unless service_tasks.include?(temp)
        end
      end
    end
  end
=end
  service_tasks.each do |task|
    service_states[task] = {}
  end
  File.open(auto_log, "r") do |f|
    state_flag = ""
    f.each_line do |line|
      if line.include?("service_template_provision_task_")
        task = line[/.*provision_task_(.*)\]\)/, 1]
        if service_states.key?(task)
          if line.match?(/service_template_provision_task.*Processing\sState/)
            state = line[/Processing\sState=\[(.*)\]/, 1]
            state_flag = state
            if service_states[task].key?(state)
              service_states[task][state] += 1
            else
              service_states[task][state] = 1
            end
          elsif line.include?("Child Service:")
            service_name = line[/.*Child\sService:\s(.*)/, 1]
            puts
            puts "Service name: ".white + "#{service_name}".light_green
            puts
          elsif line.include?("Grandchild Task")
            if line.include?("Desc")
              grand_task = line[/.*Grandchild Task:\s(.*)/, 1]
              task_id = grand_task[/(.*)\sDesc.*/, 1]
              template = grand_task[/Provision\sfrom\s\[(.*)\]\sto/, 1]
              vm_name = grand_task[/to\s\[(.*)\]/, 1]
              type = line[/type:\s(.*)/, 1]
              puts "    Grandchild Task: ".white + "#{task_id}".light_green + " Desc: Provision from [" + "#{template}".light_green + "] to [" + "#{vm_name}".light_green + "] type: " + "#{type}".light_green
              #puts "    Grandchild Task: #{grand_task}"
              miq_tasks.push(task_id)
            else
              puts "    Perhaps Custom Grandchild Task".white + ": #{line}.light_green"
            end

          elsif line.include?("catalogbundleinitialization> Setting service attribute: name")
            bundle_name = line[/name\sto:\s(.*)/, 1]
            puts
            puts "Catalog Bundle: ".white + "#{bundle_name}".light_green
          elsif line.include?("Updated")
              namespace = line.split(" ")
              custom_code.push("    Service Task:".white + " #{task}".light_green + " used custom code in " + "State:".white + " #{state_flag}".light_green + ", " + "Namespace:".white + " #{namespace.last.chomp(']')}".red + ", " + "Overwriting:".white + " #{namespace[-2][1..-1]}".light_green) unless namespace.last.start_with?("ManageIQ") || !namespace[-2].start_with?("[miqaedb")
          end
        end  
      end
    end
  end
  puts
  puts "Total Service Tasks:".white
  puts
  service_states.each do |task_id, state|
    print "    Service task: ".white + "#{task_id}".light_green + ", with states: {"
    count = 0
    state.each do |k,v|
      print "\"" + "#{k}".white + "\"=>\"" + "#{v}".light_green + "\""
      count += 1
      if count < state.length 
        print ", "
      else
        puts "}"
      end      
    end
  end
  puts  
  puts "Custom Code Used:".white unless custom_code.length == 0
  puts
  custom_code.each do |line|
    puts line
  end
  puts
  puts "Total Miq Tasks:".white
  puts
  miq_task auto_log, miq_tasks
  puts
  return service_tasks, miq_tasks
end

def miq_task auto_log, miq_tasks
  miq_states = {}
  miq_tasks.each do |task|
    miq_states[task] = {}
    miq_states[task]["ERROR"] = []
  end
  custom_code = []
  state_flag = ""
  File.open(auto_log, "r") do |f|
    f.each_line do |line|
      if line.include?("miq_provision_")
        task = line[/.*miq_provision_(.*)\]\)/, 1]
        if miq_states.key?(task)
          if line.match?(/miq_provision_.*Processing\sState/)
            state = line[/Processing\sState=\[(.*)\]/, 1]
            state_flag = state
            if miq_states[task].key?(state)
              miq_states[task][state] += 1
            else
              miq_states[task][state] = 1
            end
          elsif line.include?("Updated")
              namespace = line.split(" ")
              custom_code.push("#{task} used custom code in State: " + "#{state_flag}".light_green + ", Namespace: " + "#{namespace.last.chomp(']')}".red + ", Overwriting: #{namespace[-2][1..-1]}") unless namespace.last.start_with?("ManageIQ") || !namespace[-2].start_with?("[miqaedb")
          elsif line.include?("ERROR") || line.include?("WARN")
            miq_states[task]["ERROR"].push(line)
          end
        end
      end
    end
  end
  miq_states.each do |task_id, states|
    print "    Miq Task: ".white + "#{task_id}".light_green + ", with states: {"
    count = 0
    states.each do |k,v|
      print "\"" + "#{k}".white + "\"=>\"" + "#{v}".light_green + "\""
      count += 1
      if count < states.length 
        print ", "
      else
        puts "}"
      end      
    end
  end
  puts
  puts "Custom code used:".white
  puts
  custom_code.each do |line|
    puts "    Task ".white + "#{line}"
  end
end

def lifecycle auto_log, evm_log, request_id
  provision = {}
  request_id.each do |id|
    provision[id]={}
  end
  miq_tasks = []
  File.open(evm_log, "r") do |f|
    f.each_line do |line|
      if line.include?("request\"=>\"vm_provision")
        request = line[/miq_provision_request_(.*)\]\)/, 1]
        if request_id.include?(request)
          task = line[/object_id=>(.*),\s:attrs/, 1]
          provision[request]["miq_provision"]=task
          miq_tasks.push(task)
        end
      end
    end
  end
  miq_task auto_log, miq_tasks
end

time = Time.now.getutc
auto_log, evm_log = ARGV
request_id = ARGV.drop(2)
system "clear" or system "cls"
cli = HighLine.new
puts "Please select the type of provision:"
puts "[1] Service Provision"
puts "[2] Lifecycle Provision"
selection = cli.ask("Selection: ", Integer) {|q| q.in = 1..2}
system "clear" or system "cls"
if selection == 1
  miq_tasks = []
  services = {}
  task_id = []
  bundle = false
  request_id.each do |x|
    services[x] = service_request auto_log, evm_log, x
  end
  puts "------------------------------------SERVICES-----------------------------------------".white
  puts
  services.each do |request_id, service_tasks|
    print "Service Request ID: ".white
    puts "#{request_id}".light_green
    puts
    bundle = the_real_deal auto_log, evm_log, service_tasks
    puts
  end
  puts "---------------------------------END OF SERVICES--------------------------------------".white
  puts
  puts
  puts
  services.each do |request_id, service_tasks|
    puts "-------------------------------------STARTING-----------------------------------------".white
    puts
    print "Request ID: ".white
    puts "#{request_id}".light_green
  
    service_task auto_log, evm_log, service_tasks, bundle
    puts
    puts "---------------------------------------DONE-------------------------------------------".white
    puts
    puts
    puts
  end
elsif selection == 2
  lifecycle auto_log, evm_log, request_id  
end

time2 = Time.now.getutc
time3 = time2 - time
puts "It took: #{time3}"
