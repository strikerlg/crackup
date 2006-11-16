require 'digest/sha2'

module Crackup
  
  # Represents a filesystem object on the local filesystem.
  module FileSystemObject
    attr_reader :name, :name_hash
    
    def initialize(name)
      @name      = name.chomp('/')
      @name_hash = Digest::SHA256.hexdigest(name)
    end
    
    def remove; end
    def restore(local_path); end
  end

end