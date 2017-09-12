class CreateCangarooConnections < Cangaroo::Migration[4.2]
  def change
    create_table :cangaroo_connections do |t|
      t.string :name
      t.string :url
      t.string :key
      t.string :token

      t.timestamps null: false
    end
  end
end
