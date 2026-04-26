class AddSourceToDefaultPricings < ActiveRecord::Migration[8.1]
  def change
    add_column :default_pricings, :source, :string
    add_index  :default_pricings, :source
  end
end
