# Pictures a shop's buyers pick from (their zodiac sign, their dog's breed), kept once for the
# shop and offered by any of its products' choice fields, instead of on each product.
class CreateClipartSets < ActiveRecord::Migration[8.1]
  def change
    create_table :clipart_sets do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
  end
end
