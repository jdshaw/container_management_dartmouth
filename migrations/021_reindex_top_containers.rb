require 'db/migrations/utils'

Sequel.migration do

  up do
    self[:top_container].update(:system_mtime => Time.now)
  end

  down do
  end

end