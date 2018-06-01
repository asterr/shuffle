require 'win32/shortcut'
require 'fileutils'
require 'json'
include Win32

@srcdirs = [
  "C:/Users/asterr/Pictures/ZFinal/Processed-Albums",
  "C:/Users/asterr/Pictures/ZFinal/Processed-Albums/OLD"
]
@target = "C:/Users/asterr/Pictures/shuffled"
@history = "C:/Users/asterr/Pictures/shuffled/history.json"
@suppress_days = 180

class Album
  def initialize(path)
    @path = path
  end

  def fullpath
    @path
  end

  def name
    File.basename(@path)
  end

  def age
    return @age if @age
    timestamp_file = File.join(fullpath,'timestamp.txt') 
    if File.readable?(timestamp_file)
      timestamp = File.read(timestamp_file).chomp.to_i
    else
      timestamp = File.stat(fullpath).ctime.to_i
    end
    @timestamp = Time.at(timestamp)
    @age ||= (Time.now.to_i - timestamp)/(60*60*24*30*6)
  end

  def age_score
    # @age_score ||= rand(100) * Math.log(10 + age)
    @age_score ||= rand(100) * (1.0 / Math.log(10 + age))
  end
end

class Picture
  def initialize(path)
    @path = path
  end

  def fullpath
    @path
  end

  def name
    File.basename(@path)
  end

  def age
    return @age if @age
    @age ||= (Time.now.to_i - File.stat(fullpath).ctime.to_i)/(60*60*24*30*6)
    @timestamp = Time.at(@age)
    return @age
  end

  def age_score
    # @age_score ||= rand(100) * Math.log(10 + age)
    @age_score ||= rand(100) * (1.0 / Math.log(10 + age))
  end

  def year
    @timestamp.year.to_s
  end
end

class DatedArray < Array
  def sort_random_date
    self.sort {|a,b| b.age_score <=> a.age_score }
  end
end

def listalbums
  albums = DatedArray.new

  @srcdirs.each do |dir|
    Dir.glob(File.join(dir,'*')).each do |album|
      next if album =~ /\/OLD$/
      if last_seen = @current_history[album]
        next unless Time.at(last_seen) < (Time.now - (60*60*24*@suppress_days))
      end
      albums << Album.new(album)
    end
  end
  return albums
end

def listpictures
  pictures = DatedArray.new
  Dir.glob("C:/Users/asterr/Pictures/ZFinal/Processed*/*.jpg").each do |pic|
    next if pic =~ /Processed-Albums/
    if last_seen = @current_history[pic]
      next unless Time.at(last_seen) < (Time.now - (60*60*24*@suppress_days*4))
    end
    pictures << Picture.new(pic)
  end
  return pictures
end

def newfolder
  time = Time.now.strftime('%Y%m%dT%H%M')
  path = File.join(@target,time)
  Dir.mkdir(path)
  return path
end 


def linkrandom(folder,albums)
  albums.sort_random_date[0..2].each do |album|
    @current_history[album.fullpath] = Time.now.to_i
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

def linkrandompics(folder,pictures)
  picfolder = folder #File.join(folder,'00000pictures')
  #Dir.mkdir(picfolder)
  pictures.sort_random_date[0..14].each do |pic|
    @current_history[pic.fullpath] = Time.now.to_i
    # key  = rand(1000).to_s
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


#Shortcut.new(File.join(@target,"foo.lnk")) do |s|
#  s.description            = 'test link'
#  s.path                   = File.join(@srcdir,"Pictures")
#  s.show_cmd               = Shortcut::SHOWNORMAL
#  s.working_directory      = "C:/"
#end


puts "hello"

if File.readable?(@history)
  @current_history = JSON.parse(File.read(@history))
else
  @current_history = Hash.new
end

pictures = listpictures
albums = listalbums
#puts albums.sort_random_date.reverse.map{|a| a.name + " :: " + a.age.to_s + " :: " + a.age_score.to_s}

folder = newfolder
linkrandompics(folder,pictures)
linkrandom(folder,albums)

File.open(@history, 'w') do |f|
  f.puts JSON.generate(@current_history)
end

system("explorer C:\\Users\\asterr\\Pictures\\Shuffled")