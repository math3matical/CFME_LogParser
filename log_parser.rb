require 'rubygems'
require 'curb'

$stdout.puts 'Yes! It works.'

def scan
  x=0
  File.open(ARGV[0],"r") do |f|
    f.each_line do |line|
      if line.include?("local=")
        appliance line
      elsif line.include?("count for state")
        queue line
      end
    end
  end
  return x
end

$appliances=Hash.new
$q_dequeue=Hash.new
$q_error = Hash.new
$q_ready = Hash.new

start_time = Time.now.getutc

def appliance line
#scan "local=" do |line|
  appliances = Hash.new
  mark1 = "id="
  mark2 = ", pid="
  mark3 = "name="
  mark4 = ", zone="
  mark5 = ", hostname="
  mark6 = ", ipaddress="
  mark7 = "active roles="
  id=line[/#{mark1}(.*?)#{mark2}/m, 1]
  unless $appliances.key? id then 
    hostname=line[/#{mark5}(.*?)#{mark6}/m, 1]
    name=line[/#{mark3}(.*?)#{mark4}/m, 1]
    zone=line[/#{mark4}(.*?)#{mark5}/m, 1]
    roles=line[/#{mark7}(.*?)\z/m, 1]
    $appliances[id]=[name,zone,hostname,roles,0]
  else $appliances[id][4] +=1
  end
end

def queue line
  if line.include? "dequeue"
    b=line[/.*zone\sand\srole:\s(.*?)$/m, 1]
    b.slice!("{")
    while b.length > 0
      #$stdout.puts ""
      #$stdout.puts "oringinal b: #{b}"
      c = b[/^([^}]*)}/m,1] + "}"
      #$stdout.puts "c: #{c}"
      b.slice!(c)
      b.slice!(/^,\s/)
      #c.slice!("{")
      d=c[/([^=]*)?/]  # get the zone name
      #$stdout.puts "d: #{d}"
      c.slice!(d)
      c.sub!("=>{","")
      q = Hash.new
      while c.length > 0
        #$stdout.puts "ok, so originall c is : #{c}"
        e=c[/([^=]*)?/]  # get the role name
        e = "nil" if (e==nil)
        #$stdout.puts "c: #{c}"
        #$stdout.puts "e: #{e}"
        #$stdout.puts "this is e, the role name: #{e}"
        c.slice!(e)
        c.sub!("=>","")
        f=c[/([^,]*)?/]  # get the count of tasks with given role name
        #$stdout.puts "yo, c is : #{c}"
        #q = Hash.new
        #$stdout.puts "c: #{c}"
        c.slice!(f)
        c.sub!(", ","")
        #$stdout.puts "c: #{c}"
        #e = "butt" if e == nil
        e.gsub!("\"","") if e[0] == "\"" 
        q[e] = [f.to_i,1]
        if $q_dequeue.key?(d) then
                #$stdout.puts "q_queue[d]: #{$q_dequeue[d]}"
                #$stdout.puts "q[e][0]: #{q[e][0]}"
          #$stdout.puts "q_dequeue[d]: #{$q_dequeue[d]}"
          #$stdout.puts "q_deququq[d][e]: #{$q_dequeue[d][e]}, d: #{d}, e: #{e}"
          if $q_dequeue[d].key?(e)
            $q_dequeue[d][e][0] += q[e][0]
            $q_dequeue[d][e][1] += q[e][1]
          else
            $q_dequeue[d][e] = q[e]
          end
        else
          $q_dequeue[d] = q
        end
        #q[e] = [f,1]

        #airay.push(Hash.new(d,e)
      end
        
      #$q_dequeue[d]=c
    end

    #$q_dequeue[$q_dequeue.length]=line[/.*zone\sand\srole:\s(.*?)$/m, 1]
  elsif line.include? "error"
    $q_error[$q_error.length]=line[/.*zone\sand\srole:\s(.*?)$/m, 1]
  elsif line.include? "ready"
    $q_ready[$q_ready.length]=line[/.*zone\sand\srole:\s(.*?)$/m, 1]
  end
end

def automate line, request
  if line.include?(request)
    puts "heck yeah!"
  end
end

scan 
#scan marker do |line|


end_time = Time.now.getutc

$stdout.puts"Started at: #{start_time}, Ended at: #{end_time}"

total_time = end_time - start_time
$stdout.puts "The elapsed time?: #{total_time}"

sorted_appliances = $appliances.sort_by {|k,y|k}
$stdout.puts "Appliances:"
count = 1
sorted_appliances.each do |x,y|
  $stdout.puts "  [#{count}] ID: [#{x}], Name: [#{y[0]}], Zone: [#{y[1]}], Hostname: [#{y[2]}] and Count: [#{y[4]}]"
  $stdout.puts "          Appliance roles: #{y[3]}"
  $stdout.puts ""
  count +=1
end

$stdout.puts "Dequeue: #{$q_dequeue.length}"
$stdout.puts "Error: #{$q_error.length}"
$stdout.puts "Ready: #{$q_ready.length}"

$q_dequeue.each do |x,y|
  $stdout.puts "Zone #{x}: "
  y.each do |a,b|
    x = b[0]/b[1].to_f
    x.round(2)
    $stdout.print "    "
    $stdout.puts "#{a}: #{x.round(2)}"
  end
  $stdout.puts ""
end
