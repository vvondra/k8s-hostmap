require 'sinatra'
require 'json'
require 'sinatra/reloader' if development?

get '/' do
  nodes = JSON.parse!(File.read('nodes.json'), symbolize_names: true)[:items]
  @nodes_by_ip = nodes.group_by do |node|
    addresses = node.dig(:status, :addresses)
    puts addresses if addresses.nil?
    break 'nil' if addresses.nil?
    address = addresses.detect { |a| a[:type] == 'InternalIP' }
    address[:address]
  end

  pods = JSON.parse!(File.read('all.json'), symbolize_names: true)[:items]
  @pods_by_ip = pods.group_by { |i| i.dig(:status, :hostIP) }

  @top_nodes = File.open('top_nodes.tsv')
             .each_line
             .drop(1)
             .map { |line| line.split(' ') }
             .map { |line|
                {
                  ip: line[0].gsub(/ip-(\d+)-(\d+)-(\d+)-(\d+).+/, '\1.\2.\3.\4'),
                  cpu_cores: line[1],
                  cpu_perc: line[2].to_i,
                  mem: line[3],
                  mem_perc: line[4].to_i
                }
             }
             .group_by { |line| line[:ip] }
             .transform_values { |v| v.first }

  erb :index
end

helpers do
  def mebibytes(text)
    return 10 if text.nil? or text.empty?
    value = text.to_i
    case text.gsub(/\d+/, '')
      when 'Mi'
        value
      when 'Ki'
        value / 1024
      else
        value / 1024 / 1024 # assume bytes
    end
  end
end
