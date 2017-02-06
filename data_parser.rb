#!/usr/bin/env ruby
require 'pry'
require 'csv'

IN = ARGV.first || 'planet_express_logs.csv'
BUFFER = '.buffer'
CONSOLE = IO.new(IO.sysopen('/dev/tty','w'),'w')
PAYROLL = (ARGV.last if ARGV.count > 1) || ''
COMMISSION = 0.1

class Pilot
  attr_accessor :pilot, :trips, :revenue, :commission

  def initialize(pilot, trips, revenue, commission)
    @pilot, @trips, @revenue, @commission = pilot, trips, revenue, commission
  end

  def update(revenue,commission)
    self.trips += 1
    self.revenue += revenue
    self.commission += commission
  end

end

class Delivery
  attr_accessor :destination, :package, :crates, :payment, :commission, :pilot

  def initialize(destination,package,crates,payment)
    @destination,@package,@crates,@payment = destination,package,crates.to_i,payment.to_f
    @commission = @payment * COMMISSION
    @pilot = case @destination
             when 'Earth' then 'Fry' when 'Mars' then 'Amy' when 'Uranus' then 'Bender'
             else 'Leela'
             end

    # check if pilot is already recorded in PILOTS; create/update as appropriate
    assign(@pilot)&.update(@payment,@commission) || PILOTS << Pilot.new(@pilot,1,@payment,@commission)

    PARSE.update(@destination,@pilot,@payment,@package)

  end

  def assign(assignee)
    PILOTS.detect { |e| e.pilot == assignee }
  end

end

class Parse
  attr_accessor :total_revenue, :planet_revenue, :pilot_revenue, :pilot_commission, :pilot_trips

  def initialize(total_revenue=0.0, planet_revenue={}, pilot_revenue={}, pilot_commission={}, pilot_trips={})
    @total_revenue, @planet_revenue, @pilot_revenue, @pilot_commission, @pilot_trips = total_revenue, planet_revenue, pilot_revenue, pilot_commission, pilot_trips
  end

  def update(planet,pilot,revenue,package)
    self.total_revenue += revenue
    self.planet_revenue[planet.to_sym] = self.planet_revenue[planet.to_sym].to_f + revenue
    self.pilot_revenue[pilot.to_sym] = self.pilot_revenue[pilot.to_sym].to_f + revenue
    self.pilot_commission[pilot.to_sym] = self.pilot_commission[pilot.to_sym].to_f + revenue * COMMISSION
    self.pilot_trips[pilot.to_sym] = self.pilot_trips[pilot.to_sym].to_i + 1
  end

  def get_revenue
    self.total_revenue
  end

  def write_employee_bonuses
    self.pilot_commission.map{|p|"#{p.first} (#{p.last})"}.join(', ')
  end

  def write_employee_trips
    self.pilot_trips.map{|p|"#{p.first} (#{p.last})"}.join(', ')
  end

  def write_planetary_revenue
    self.planet_revenue.map{|p|"#{p.first} (#{p.last})"}.join(', ')
  end

  def generate_payroll(file_name)
    unless file_name.empty?
      CSV.open(file_name, 'wt') do |csv|
        csv << ['Pilot', 'Shipments', 'Total Revenue', 'Payment']
        PILOTS.each { |x| csv << [x.pilot,x.trips,x.revenue,x.commission] }
      end
    end
  end

  def construct_deliveries_table
    delivery_table_header = "Deliveries this week:\n\n" +
      "\t\tPLANET\t\tPACKAGE\t\tCRATES\t\tPAYMENT\t\tPILOT\n\n"
    delivery_table = DELIVERIES.map do |d|
      "\t\t#{d.destination}" +
      "\t\t#{d.package[0..6]}" +
      "\t\t#{d.crates.to_s}" +
      "\t\t#{d.payment.to_i.to_s}" +
      "\t\t#{d.pilot}\n"
    end
    File.open(BUFFER, 'a+') do |o|
      delivery_table.unshift(delivery_table_header).map{|d|o.write(d)}
    end
  end

  def parse_data(file_name)
    File.open(BUFFER, 'wt') do |o|
      o.write( "How much money did we make this week?" +
               "\t\t#{get_revenue}\n\n" )
      o.write( "How much of a bonus did each employee get?" +
               "\t#{write_employee_bonuses}\n\n" )
      o.write( "How many trips did each employee make?" +
               "\t\t#{write_employee_trips}\n\n" )
      o.write( "How much did we make per planet?" +
               "\t\t#{write_planetary_revenue}\n\n" )
    end

    construct_deliveries_table

    CONSOLE << "\n#{File.read(BUFFER)}" #write to console

    generate_payroll(file_name)

  end

end

PARSE, PILOTS = Parse.new, []
DELIVERIES = CSV.read(IN).drop(1).map { |d| Delivery.new( *d[0..3] ) }
PARSE.parse_data(PAYROLL)

CONSOLE.close
File.delete(BUFFER) if File.exist?(BUFFER)

binding.pry
