#!/usr/bin/env ruby
#
# crackup - command-line tool for performing Crackup backups. See 
# <tt>crackup -h</tt> for usage information.
#
# Author::    Ryan Grove (mailto:ryan@wonko.com)
# Version::   1.0.0
# Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
# License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
#

require 'crackup'
require 'optparse'

APP_NAME      = 'crackup'
APP_VERSION   = '1.0.0'
APP_COPYRIGHT = 'Copyright (c) 2006 Ryan Grove (ryan@wonko.com). All rights reserved.'
APP_URL       = 'http://wonko.com/software/crackup'

module Crackup
  @options = {
    :from       => ['.'],
    :exclude    => [],
    :passphrase => nil,
    :to         => nil,
    :verbose    => false
  }
  
  optparse = OptionParser.new do |optparse|
    optparse.summary_width  = 24
    optparse.summary_indent = '  '
    
    optparse.banner = "Usage: #{File.basename(__FILE__)} -t <url> [-p <pass>] [-v] [<file|dir> ...]"
    optparse.separator ''
    
    optparse.on '-p', '--passphrase <pass>',
        'Encryption passphrase (if not specified, no',
        'encryption will be used)' do |passphrase|
      @options[:passphrase] = passphrase
    end
    
    optparse.on '-t', '--to <url>',
        'Destination URL (e.g.,',
        'ftp://user:pass@server.com/path)' do |url|
      @options[:to] = url.gsub("\\", '/').chomp('/')
    end
    
    optparse.on '-v', '--verbose',
        'Verbose output' do
      @options[:verbose] = true
    end
    
    optparse.on '-x', '--exclude <file>',
        'Exclude files and directories whose names match the',
        'list in the specified file' do |filename|
      unless File.file?(filename)
        error "Exclusion list does not exist: #{filename}"
      end
      
      unless File.readable?(filename)
        error "Exclusion list is not readable: #{filename}"
      end
      
      begin
        @options[:exclude] = File.readlines(filename)
        @options[:exclude].map! {|item| item.chomp }
      rescue => e
        error "Error reading exclusion file: #{e}"
      end
    end
    
    optparse.on_tail '-h', '--help',
        'Display usage information (this message)' do
      puts optparse
      exit
    end
    
    optparse.on_tail '--version',
        'Display version information' do
      puts "#{APP_NAME} v#{APP_VERSION} <#{APP_URL}>"
      puts "#{APP_COPYRIGHT}"
      puts
      puts "#{APP_NAME} comes with ABSOLUTELY NO WARRANTY."
      puts
      puts "This program is open source software distributed under the terms of"
      puts "the New BSD License. For details, see the LICENSE file contained in"
      puts "the source distribution."
      exit
    end
  end
  
  # Parse command line options.
  begin
    optparse.parse!(ARGV)
  rescue => e
    abort("Error: #{e}")
  end
  
  # Add files to the "from" array.
  if ARGV.length
    @options[:from] = []
    
    while filename = ARGV.shift
      @options[:from] << filename.chomp('/')
    end
  end
  
  # Load driver.
  begin
    @driver = Crackup::Driver.get_driver(@options[:to])
  rescue => e
    error e
  end
  
  # Get the remote file index.
  debug 'Retrieving remote file index...'
  
  begin
    @remote_index = Crackup::Index.get_remote_index(
        "#{@options[:to]}/.crackup_index")
  rescue => e
    error e
  end
  
  # Build a list of local files and directories.
  debug 'Building local file list...'
  
  begin
    @local_files = get_local_files()
  rescue => e
    error e
  end
  
  # Determine differences.
  debug 'Determining differences...'  
  begin
    update = get_updated_files(@local_files, @remote_index)
    remove = get_removed_files(@local_files, @remote_index)
  rescue => e
    error e
  end
  
  # Remove files from the remote location if necessary.
  unless remove.empty?
    debug 'Removing stale files from remote location...'
    
    begin
      remove_files(remove)
    rescue => e
      error e
    end
  end
  
  # Update files at the remote location if necessary.
  unless update.empty?
    debug 'Updating remote location with new/changed files...'
    
    begin
      update_files(update)
    rescue => e
      error e
    end
  end
  
  # Update the remote file index if necessary.
  unless remove.empty? && update.empty?
    debug 'Updating remote index...'
    
    begin
      @remote_index.upload("#{@options[:to]}/.crackup_index")
    rescue => e
      error e
    end
  end
  
  debug 'Finished!'
end