ActiveRecord::Schema.define do
  create_table(:companies, :force => true) do |t|
    t.string :name
    t.string :description
    t.string :url
    t.integer :user_count, default: 0, null: false
    t.boolean :active, default: true, null: false
    t.string :exchange_routing_keys
    t.integer :points_per_user, default: 1, null: false
    t.integer :total_points, default: 0, null: false
    t.timestamps
  end

  create_table(:users, :force => true) do |t|
    t.references :company
    t.string :first_name
    t.string :last_name
    t.string :encrypted_password
    t.string :email
    t.boolean :is_admin
    t.boolean :deactivated
    t.integer :login_count, default: 0, null: false
    t.string :keys
    t.string :exchange_routing_keys
    t.timestamps
  end
end
