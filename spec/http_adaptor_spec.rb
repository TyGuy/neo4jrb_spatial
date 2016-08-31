require 'spec_helper'

describe Neo4j::Core::Spatial::HTTPAdaptor do
  let(:neo) { Neo4j::ActiveBase.current_session }

  describe 'find the spatial plugin' do
    it 'can get a description of the spatial plugin' do
      si = neo.spatial_plugin
      expect(si).not_to be_nil
      expect(si[:graphdb][:addEditableLayer]).not_to be_nil
    end
  end

  describe 'add a point layer' do
    it 'can add a simple point layer' do
      pl = neo.add_point_layer('restaurants')
      expect(pl).not_to be_nil
      expect(pl.first[:data][:layer]).to eq('restaurants')
      expect(pl.first[:data][:geomencoder_config]).to eq('lon:lat')
    end

    it 'can add a simple point layer with lat and long' do
      pl = neo.add_point_layer('coffee_shops', 'latitude', 'longitude')
      expect(pl).not_to be_nil
      expect(pl.first[:data][:layer]).to eq('coffee_shops')
      expect(pl.first[:data][:geomencoder_config]).to eq('longitude:latitude')
    end
  end

  describe 'add an editable layer' do
    it 'can add an editable layer' do
      el = neo.add_editable_layer('zipcodes', 'WKT', 'wkt')
      expect(el).not_to be_nil
      expect(el.first[:data][:layer]).to eq('zipcodes')
      expect(el.first[:data][:geomencoder_config]).to eq('wkt')
    end
  end

  describe 'get a spatial layer' do
    it 'can get a layer' do
      sl = neo.get_layer('restaurants')
      expect(sl).not_to be_nil
      expect(sl.first[:data][:layer]).to eq('restaurants')
    end
  end

  describe 'create a spatial index' do
    it 'can create a spatial index' do
      index = neo.create_spatial_index('restaurants')
      expect(index[:provider]).to eq('spatial')
      expect(index[:geometry_type]).to eq('point')
      expect(index[:lat]).to eq('lat')
      expect(index[:lon]).to eq('lon')
    end
  end

  describe 'add geometry to spatial layer' do
    it 'can add a geometry' do
      geometry = 'LINESTRING (15.2 60.1, 15.3 60.1)'
      geo = neo.add_geometry_to_layer('zipcodes', geometry)
      expect(geo).not_to be_nil
      expect(geo.first[:data][:wkt]).to eq(geometry)
    end
  end

  describe 'update geometry from spatial layer' do
    it 'can update a geometry' do
      geometry = 'LINESTRING (15.2 60.1, 15.3 60.1)'
      geo = neo.add_geometry_to_layer('zipcodes', geometry)
      expect(geo).not_to be_nil
      expect(geo.first[:data][:wkt]).to eq(geometry)
      geometry = 'LINESTRING (14.7 60.1, 15.3 60.1)'
      existing_geo = neo.edit_geometry_from_layer('zipcodes', geometry, geo)
      expect(existing_geo.first[:data][:wkt]).to eq(geometry)
      expect(existing_geo.first[:self].split('/').last.to_i).to eq(geo.first[:self].split('/').last.to_i)
    end
  end

  describe 'add a node to a layer' do
    it 'can add a node to a simple point layer' do
      properties = {name: "Max's Restaurant", lat: 41.8819, lon: 87.6278}
      query_obj = Neo4j::Core::Query.new.create(n: {Restaurant: properties}).return(:n)
      node = neo.query(query_obj).first[:n]
      expect(node).not_to be_nil
      added = neo.add_node_to_layer('restaurants', node)
      expect(added.first[:data][:lat]).to eq(properties[:lat])
      expect(added.first[:data][:lon]).to eq(properties[:lon])

      added = neo.add_node_to_spatial_index('restaurants', node)
      expect(added[:data][:lat]).to eq(properties[:lat])
      expect(added[:data][:lon]).to eq(properties[:lon])
    end
  end

  describe 'find geometries in a bounding box' do
    it 'can find a geometry in a bounding box' do
      properties = {name: "Max's Restaurant", lat: 41.8819, lon: 87.6278}
      nodes = neo.find_geometries_in_bbox('restaurants', 87.5, 87.7, 41.7, 41.9)
      expect(nodes).not_to be_empty
      result = nodes.find { |node| node[:data][:name] == "Max's Restaurant" }
      expect(result[:data][:lat]).to eq(properties[:lat])
      expect(result[:data][:lon]).to eq(properties[:lon])
    end

    it 'can find a geometry in a bounding box using cypher' do
      properties = {lat: 60.1, lon: 15.2}
      neo.create_spatial_index('geombbcypher', 'point', 'lat', 'lon')
      query_obj = Neo4j::Core::Query.new.create(n: {dummy: properties}).return(:n)
      node = neo.query(query_obj).first[:n]
      neo.add_node_to_spatial_index('geombbcypher', node)
      query_obj = Neo4j::Core::Query.new.start("node = node:geombbcypher('bbox:[15.0,15.3,60.0,60.2]')").return(:node)
      existing_node = neo.query(query_obj).first[:node]
      expect(existing_node).not_to be_nil
      expect(existing_node.props[:lat]).to eq(properties[:lat])
      expect(existing_node.props[:lon]).to eq(properties[:lon])
    end

    it 'can find a geometry in a bounding box using cypher two' do
      properties = {lat: 60.1, lon: 15.2}
      neo.create_spatial_index('geombbcypher2', 'point', 'lat', 'lon')
      query_obj = Neo4j::Core::Query.new.create(n: {[] => properties}).return(:n)
      node = neo.query(query_obj).first[:n]
      neo.add_node_to_spatial_index('geombbcypher2', node)
      query_obj = Neo4j::Core::Query.new.start("node = node:geombbcypher2('bbox:[15.0,15.3,60.0,60.2]')").return(:node)
      existing_node = neo.query(query_obj).first[:node]
      expect(existing_node).not_to be_nil
      expect(existing_node.props[:lat]).to eq(properties[:lat])
      expect(existing_node.props[:lon]).to eq(properties[:lon])
    end
  end

  describe 'find geometries within distance' do
    it 'can find a geometry within distance' do
      properties = {name: "Max's Restaurant", lat: 41.8819, lon: 87.6278}
      nodes = neo.find_geometries_within_distance('restaurants', 87.627, 41.881, 10)
      expect(nodes).not_to be_empty
      result = nodes.find { |node| node[:data][:name] == "Max's Restaurant" }
      expect(result[:data][:lat]).to eq(properties[:lat])
      expect(result[:data][:lon]).to eq(properties[:lon])
    end

    it 'can find a geometry within distance using cypher' do
      properties = {lat: 60.1, lon: 15.2}
      neo.create_spatial_index('geowdcypher', 'point', 'lat', 'lon')
      query_obj = Neo4j::Core::Query.new.create(n: {[] => properties}).return(:n)
      node = neo.query(query_obj).first[:n]
      neo.add_node_to_spatial_index('geowdcypher', node)
      query_obj = Neo4j::Core::Query.new.start('n = node:geowdcypher({bbox})').params(bbox: 'withinDistance:[60.0,15.0,100.0]').return(:n)
      existing_node = neo.query(query_obj).first[:n]
      expect(existing_node).not_to be_nil
      expect(existing_node.props[:lat]).to eq(properties[:lat])
      expect(existing_node.props[:lon]).to eq(properties[:lon])
    end

    it 'can find a geometry within distance using cypher 2'  do
      properties = {lat: 60.1, lon: 15.2}
      neo.create_spatial_index('geowdcypher2', 'point', 'lat', 'lon')
      query_obj = Neo4j::Core::Query.new.create(n: {[] => properties}).return(:n)
      node = neo.query(query_obj).first[:n]
      neo.add_node_to_spatial_index('geowdcypher2', node)
      query_obj = Neo4j::Core::Query.new.start('n = node:geowdcypher2({bbox})').params(bbox: 'withinDistance:[60.0,15.0,100.0]').return(:n)
      existing_node = neo.query(query_obj).first[:n]
      expect(existing_node).not_to be_nil
      expect(existing_node.props[:lat]).to eq(properties[:lat])
      expect(existing_node.props[:lon]).to eq(properties[:lon])
    end
  end
end
