require 'sinatra'
require 'json'
require 'net/http'
require 'sinatra/reloader' if development?

pods_url = URI('http://localhost:8001/api/v1/namespaces/default/pods?limit=500')
nodes_url = URI('http://localhost:8001/api/v1/nodes')
heapster_pods_url = URI('http://localhost:8001/apis/metrics.k8s.io/v1beta1/namespaces/default/pods')
heapster_nodes_url = URI('http://localhost:8001/apis/metrics.k8s.io/v1beta1/nodes')

pods = JSON.parse!(Net::HTTP.get(pods_url), symbolize_names: true)[:items]
nodes = JSON.parse!(Net::HTTP.get(nodes_url), symbolize_names: true)[:items]
top_nodes = JSON.parse!(Net::HTTP.get(heapster_nodes_url), symbolize_names: true)[:items]
top_pods = JSON.parse!(Net::HTTP.get(heapster_pods_url), symbolize_names: true)[:items]

get '/:metric' do |metric|
  nodes_by_ip = nodes.group_by do |node|
    addresses = node.dig(:status, :addresses)
    puts addresses if addresses.nil?
    break 'nil' if addresses.nil?
    address = addresses.detect { |a| a[:type] == 'InternalIP' }
    address[:address]
  end
  @nodes_by_ip = nodes_by_ip.transform_values { |v| v.first }

  @pods_by_ip = pods.group_by { |i| i.dig(:status, :hostIP) }

  @top_nodes = top_nodes
          .map { |node|
              {
                node: node[:metadata][:name].gsub(/ip-(\d+)-(\d+)-(\d+)-(\d+).+/, '\1.\2.\3.\4'),
                cpu_used: node[:usage][:cpu],
                mem_used: node[:usage][:memory]
              }
          }
          .group_by { |row| row[:node] }
          .transform_values { |v| v.first }

  @nodes_by_ip.each do |nodeIp, node|
    @top_nodes[nodeIp][:cpu_avail] = node.dig(:status, :capacity, :cpu)
    @top_nodes[nodeIp][:mem_avail] = node.dig(:status, :capacity, :memory)
  end

  @top_pods = top_pods
          .map { |pod|
              {
                pod: pod[:metadata][:name],
                cpu_used: pod[:containers][0][:usage][:cpu],
                mem_used: pod[:containers][0][:usage][:memory]
              }
          }
          .group_by { |row| row[:pod] }
          .transform_values { |v| v.first }

  erb metric.to_sym
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

  def milicores(text)
    return 10 if text.nil? or text.empty?
    value = text.to_i
    case text.gsub(/\d+/, '')
      when 'm'
        value
      else
        value * 1023 # full cores
    end
  end
end
