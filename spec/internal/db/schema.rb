ActiveRecord::Schema.define do
  create_table(:users, :force => true) do |t|
    t.string :first_name
    t.string :last_name
    t.string :secret_key
    t.string :email
    t.integer :login_count, default: 0, null: false
    t.timestamps
  end
end
