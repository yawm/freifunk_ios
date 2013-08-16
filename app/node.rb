class Node
  include CoreLocation::DataTypes

  REMOTE_JSON = "http://graph.hamburg.freifunk.net/nodes.json"

  attr_reader :node_id, :name, :geo, :flags, :macs

  def initialize(node_id, name, geo, flags, macs)
    @node_id    = node_id
    @name       = name
    @geo        = geo
    @flags      = flags
    @macs       = macs.split(", ")
  end

  def title
    "#{online? ? '💚' : '❤'} #{name}"
  end

  def subtitle
    node_id
  end

  def coordinate
    LocationCoordinate.new(geo.first, geo.last).api
  end

  def online?
    flags["online"]
  end

  def offline?
    !online?
  end

  def gateway?
    flags["gateway"]
  end

  def client?
    flags["client"]
  end

  def valid?
    !node_id.nil? && !name.nil? && !geo.nil?
  end

  def in_valid?
    !valid?
  end

  def self.download_path
    "#{App.documents_path}/nodes.json"
  end

  def self.local_path
    "#{App.resources_path}/data/nodes.json"
  end

  def self.file_path
    File.exists?(download_path) ? download_path : local_path
  end

  def self.all
    @nodes ||= begin
      content = File.open(file_path) { |file| file.read }
      BW::JSON.parse(content)[:nodes].map do |it|
        node_id = it[:id]
        name    = it[:name]
        geo     = it[:geo]
        flags   = it[:flags]
        macs    = it[:macs]
        self.new(node_id, name, geo, flags, macs)
      end.reject(&:in_valid?)
    end
  end

  def self.sorted
    all.sort_by { |node| node.name.downcase }
  end

  def self.reset
    @nodes = nil
  end

  def self.download(&block)
    BW::HTTP.get(REMOTE_JSON) do |response|
      if state = response.ok?
        response.body.writeToFile(download_path, atomically: true)
        reset
      end
      block.call(state)
    end
  end

  def self.last_update
    File.mtime(file_path).strftime('%d.%m.%Y')
  end

  def self.check_state(&block)
    BubbleWrap::HTTP.head(REMOTE_JSON) do |response|
      if state = !!response.headers
        remote  = NSDate.dateWithNaturalLanguageString(response.headers["Last-Modified"])
        local   = File.mtime(file_path)
        state   = remote > local
      end
      block.call(state)
    end
  end
end
