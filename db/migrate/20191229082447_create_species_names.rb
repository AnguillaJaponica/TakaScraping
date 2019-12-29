class CreateSpeciesNames < ActiveRecord::Migration[5.2]
  def change
    create_table :species_names do |t|
      t.string :scientific_name, null: false, default: ''
      t.string :author_name, null: false, default: ''
      t.string :japanese_name, default: ''
      t.string :japanese_phonetic_spell, default: ''
      t.string :chinese_name, default: ''
      t.string :chinese_phonetic_spell, default: ''
      t.string :korean_name, default: ''
      t.string :korean_phonetic_spell, default: ''
      t.string :english_name, default: ''

      t.timestamps
    end
  end
end
