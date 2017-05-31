class InitialMigration < ActiveRecord::Migration
  def self.up
    create_table :redmine_cmis_attachments_project_params do |t|
      t.column :project_id, :integer
      t.column :param, :string
      t.column :value, :string
    end
  end

  def self.down
    drop_table :redmine_cmis_attachments_project_params
  end
end
