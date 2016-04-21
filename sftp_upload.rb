require 'base64'
require 'fileutils'
require 'uri'
require 'optparse'
require 'net/sftp'

options = {
  user_home: ENV['HOME'],
  private_key_file_path: nil,
  formatted_output_file_path: nil,
}

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: sftp_upload.rb [OPTIONS]"
  opt.separator ""
  opt.separator "Options (options without [] are required)"

  opt.on("--source-dir URL", "path to sourcefiles") do |value|
    options[:source_dir] = value[0] == "/" ? value :File.expand_path( File.join( options[:work_dir], value))
  end

  opt.on("--dest-dir [DESTINATIONDIR]", "local clone destination directory path") do |value|
    options[:destination_dir] = value
  end

  opt.on("-h","--help","Shows this help message") do
    puts opt_parser
  end
end

ssh_key_from_env = ENV['auth_ssh_private_key']
options[:username] = ENV['username']
options[:hostname] = ENV['hostname']
options[:work_dir] = ENV['BITRISE_SOURCE_DIR']
if ssh_key_from_env
  options[:auth_ssh_key_raw] = ssh_key_from_env
end

opt_parser.parse!

if options[:formatted_output_file_path] and options[:formatted_output_file_path].length < 1
  options[:formatted_output_file_path] = nil
end


#
# Print configs
puts '========== Configs =========='
puts " * source: #{options[:source_dir]}   #{File.directory?(options[:source_dir])}"
puts " * destination_dir: #{options[:destination_dir]}"
puts " * auth_ssh_key_raw: #{options[:auth_ssh_key_raw].to_s.empty? ? 'no SSH key provided' : '*****'}"
puts

unless options[:source_dir] and options[:source_dir].length > 0
  puts opt_parser
  exit 1
end



# -----------------------
# --- functions
# -----------------------


def write_private_key_to_file(user_home, auth_ssh_private_key)
  private_key_file_path = File.join(user_home, '.ssh/bitrise')

  # create the folder if not yet created
  FileUtils::mkdir_p(File.dirname(private_key_file_path))

  # private key - save to file
  File.open(private_key_file_path, 'wt') { |f| f.write(auth_ssh_private_key) }
  system "chmod 600 #{private_key_file_path}"

  return private_key_file_path
end


# -----------------------
# --- main
# -----------------------

# normalize input pathes
options[:destination_dir] = File.expand_path(options[:destination_dir])

if !options[:auth_ssh_key_raw].to_s.empty?
  options[:private_key_file_path] = write_private_key_to_file(options[:user_home], options[:auth_ssh_key_raw])
else
  # Auth: No Authentication information found - trying without authentication
end

# do 


$options = options

$this_script_path = File.expand_path(File.dirname(__FILE__))


class String
  def prepend_lines_with(prepend_with_string)
    return self.gsub(/^.*$/, prepend_with_string.to_s+'\&')
  end
end

def write_string_to_formatted_output(str_to_write)
  formatted_output_file_path = $options[:formatted_output_file_path]
  if formatted_output_file_path
    File.open(formatted_output_file_path, "w+") { |f|
      f.puts(str_to_write)
    }
  end
end

def export_step_output(key, value)
  IO.popen("envman add --key #{key}", 'r+') {|f|
    f.write(value)
    f.close_write
    f.read
  }
end


def do_upload()
  upload_path = File.join($options[:destination_dir])
  is_upload_success = false 
  
  Net::SFTP.start($options[:hostname], $options[:username], keys: $options[:private_key_file_path] ) do |sftp|
    
    remote_path = ""
    puts $options[:destination_dir]
    $options[:destination_dir].split('/').map do |dir|
      remote_path = File.join remote_path, dir
      puts remote_path
    begin
      sftp.dir.entries(remote_path)
    rescue
      sftp.mkdir! remote_path
    end
  end
  
    is_upload_success = sftp.upload!( $options[:source_dir], $options[:destination_dir])  do |event, uploader, *args|
    case event
    when :open then
      # args[0] : file metadata
      puts "starting upload: #{args[0].local} -> #{args[0].remote} (#{args[0].size} bytes}"
    when :put then
      # args[0] : file metadata
      # args[1] : byte offset in remote file
      # args[2] : data being written (as string)
      puts "writing #{args[2].length} bytes to #{args[0].remote} starting at #{args[1]}"
    when :close then
      # args[0] : file metadata
      puts "finished with #{args[0].remote}"
    when :mkdir then
      # args[0] : remote path name
      puts "creating directory #{args[0]}"
    when :finish then
      puts "all done!"
      return true
  end
end
 is_upload_success.methods unless is_upload_success.nil?
    ssh_no_prompt_file = 'ssh_no_prompt.sh'
    if $options[:private_key_file_path]
      ssh_no_prompt_file = 'ssh_no_prompt_with_id.sh'
    end
  end
  return is_upload_success
end

is_upload_success = do_upload()
puts "upload Is Success?: #{is_upload_success}"


if options[:private_key_file_path]
  puts " (i) Removing private key file: #{options[:private_key_file_path]}"
  system(%Q{rm -P #{options[:private_key_file_path]}})
end

exit (is_upload_success ? 0 : 1)
