require 'win32/shortcut'
require 'fileutils'
require 'json'
include Win32

#-----------------------------------------------------------
# Config Section
#-----------------------------------------------------------
module MyConfig
  class << self
    attr_accessor :srcdirs
    attr_accessor :target
    attr_accessor :history
    attr_accessor :album_threshold
    attr_accessor :picture_threshold
    attr_accessor :picture_glob

    def srcdirs
      @srcdirs ||= [
        "C:/Users/asterr/Pictures/ZFinal/Processed-Albums",
        "C:/Users/asterr/Pictures/ZFinal/Processed-Albums/OLD"
      ]
    end

    def picture_glob
      @picture_glob ||= "C:/Users/asterr/Pictures/ZFinal/Processed*/*.jpg"
    end

    def target
      @target = "C:/Users/asterr/Pictures/shuffled"
    end

    def history
      @history = "C:/Users/asterr/Pictures/shuffled/history.json"
    end

    def album_threshold
      @album_threshold ||= 180
    end

    def picture_threshold
      @picture_threshold ||= 360
    end
  end
end

class DatedArray < Array
  def sort_random_date
    self.sort {|a,b| b.age_score <=> a.age_score }
  end
end

class Folder
  def initialize(path)
    @path = path
  end

  def name
    File.basename(@path)
  end

  def fullpath
    @path
  end

  def timestamp
    return @timestamp if @timestamp
    timestamp_file = File.join(fullpath,'timestamp.txt')
    if File.readable?(timestamp_file)
      timestamp = File.read(timestamp_file).chomp.to_i
    else
      timestamp = File.stat(fullpath).ctime.to_i
    end
    @timestamp = Time.at(timestamp)
  end

  # age in six months
  def age
    day = 60 * 60 * 24
    month = 30 * day
    @age ||= self.timestamp.to_i / ( 1 * month)
  end

  def age_score
    @age_score ||= rand(100) / (Math.log2(4 + age/4))
  end

  def year
    timestamp.year.to_s
  end
end

class Album < Folder
end

class Picture < Folder
end

#-----------------------------------------------------------
# Key Logic
#-----------------------------------------------------------
def history
  return @current_history if @current_history
  if File.readable?(MyConfig.history)
    @current_history = JSON.parse(File.read(MyConfig.history))
  else
    @current_history = Hash.new
  end
end

def last_seen(path)
  history[path] || 0
end

def save_history
  File.open(MyConfig.history, 'w') do |f|
    f.puts JSON.generate(history)
  end
end

def seen_recently?(file_name,day_threshold)
  day = 60 * 60 * 24
  Time.at(last_seen(file_name)) > (Time.now - (day_threshold * day))
end

def list_all_albums
  return @albums if @albums
  @albums = DatedArray.new

  MyConfig.srcdirs.each do |dir|
    Dir.glob(File.join(dir,'*')).each do |album|
      next if album =~ /\/OLD$/
      @albums << Album.new(album)
    end
  end
  return @albums
end

def list_albums
  results = DatedArray.new
  list_all_albums.reject{ |album| seen_recently?(album.fullpath, MyConfig.album_threshold) }.each do |a|
    results << a
  end
  return results
end

def list_all_pictures
  return @pictures if @pictures
  @pictures = DatedArray.new

  Dir.glob(MyConfig.picture_glob).each do |pic|
    next if pic =~ /Processed-Albums/
    @pictures << Picture.new(pic)
  end
  return @pictures
end

def list_pictures
  results = DatedArray.new
  list_all_pictures.reject{ |pic| seen_recently?(pic.fullpath, MyConfig.picture_threshold) }.each do |p|
    results << p
  end
  return results
end

def new_folder
  time = Time.now.strftime('%Y%m%dT%H%M%S')
  path = File.join(MyConfig.target,time)
  Dir.mkdir(path)
  return path
end 

def link_random_albums(folder,albums)
  albums.sort_random_date[0..2].each do |album|
    history[album.fullpath] = Time.now.to_i
    key = rand(1000).to_s
    keyed_name= "zz" + key + '-' + album.name + '.lnk'
    path = File.join(folder,keyed_name)
    Shortcut.new(path) do |s|
      s.description       = keyed_name
      s.path              = album.fullpath
      s.show_cmd          = Shortcut::SHOWNORMAL
      s.working_directory = 'c:/'
    end    
  end
end

def link_random_pics(folder,pictures)
  picfolder = folder
  list_pictures.sort_random_date[0..14].each do |pic|
    history[pic.fullpath] = Time.now.to_i
    key  = rand(1000).to_s + '-' + pic.year
    keyed_name= "0000" + key + '-' + pic.name + '.lnk'
    path = File.join(picfolder,keyed_name)
    Shortcut.new(path) do |s|
      s.description       = keyed_name
      s.path              = pic.fullpath
      s.show_cmd          = Shortcut::SHOWNORMAL
      s.working_directory = 'c:/'
    end    
  end
end

#-----------------------------------------------------------
# Main
#-----------------------------------------------------------

case ARGV[0]
when /^stat/
  # stats
  filtered_albums = list_all_albums.select{ |a| seen_recently?(a.fullpath, MyConfig.album_threshold) }
  filtered_pictures = list_all_pictures.select{ |p| seen_recently?(p.fullpath, MyConfig.picture_threshold) }

  puts "History Size:        #{history.keys.count}"
  puts "Eligible Albums:     #{list_albums.count}"
  puts "Elibigle Pictures:   #{list_pictures.count}"
  puts "Filtered Albums:     #{filtered_albums.count}"
  puts "Filtered Pictures:   #{filtered_pictures.count}"

when /^listp/
  # listpictures
  puts "Listing New Pictures"
  list_pictures.sort{|a,b| last_seen(a.fullpath) <=> last_seen(b.fullpath) }.each do |pic|
    puts "#{Time.at(last_seen(pic.fullpath))}: #{pic.age_score}: #{pic.fullpath}"
  end

when /^lista/
  # listalbums
  puts "Listing New Albums"
  list_albums.sort{|a,b| last_seen(a.fullpath) <=> last_seen(b.fullpath) }.each do |album|
    puts "#{Time.at(last_seen(album.fullpath))}: #{album.age_score}: #{album.fullpath}"
  end

when /^lists/
  # listseen
  puts "Listing Seen Items"
  history.sort{|a,b| b[1] <=> a[1]}.each do |path, timestamp|
    next unless seen_recently?(path, MyConfig.picture_threshold)
    puts "#{Time.at(timestamp)}: #{path}"
  end

else
  puts "Generating New Shuffled Album"

  pictures = list_pictures
  albums = list_albums
  folder = new_folder
  link_random_pics(folder,pictures)
  link_random_albums(folder,albums)
  save_history

  # Open Folder
  system("explorer C:\\Users\\asterr\\Pictures\\Shuffled")
end
