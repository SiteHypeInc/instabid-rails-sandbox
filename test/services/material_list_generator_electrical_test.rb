require "test_helper"

class MaterialListGeneratorElectricalTest < ActiveSupport::TestCase
  test "general service with no devices still emits permit + equipment + labor floor" do
    result = MaterialListGenerator.call(trade: "electrical", criteria: {})

    assert_equal "electrical", result[:trade]
    assert_in_delta 1.0, result[:complexity_multiplier]

    items = result[:material_list].index_by { |i| i[:item] }
    assert_in_delta 200.0, items.fetch("Electrical Permit")[:total_cost]
    assert_in_delta 150.0, items.fetch("Equipment & Consumables")[:total_cost]
    refute items.key?("Standard Outlets (w/ wire)")
    refute items.key?("EV Charger Install + Wire Run")

    assert_in_delta 350.0, result[:total_material_cost]
    assert_in_delta 2.0, result[:labor_hours] # labor min floor
  end

  test "general service itemizes outlets gfci switches dimmers fixtures recessed and applies per-device labor" do
    result = MaterialListGenerator.call(
      trade:    "electrical",
      criteria: {
        serviceType:    "general",
        outletCount:    10,
        gfciCount:      3,
        switchCount:    8,
        dimmerCount:    2,
        fixtureCount:   6,
        recessedCount:  4,
        ceilingFanCount: 1
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # outlets: 10 * (12 + 25*1.0) = 370
    assert_in_delta 370.0, items.fetch("Standard Outlets (w/ wire)")[:total_cost]
    # gfci: 3 * (35 + 25) = 180
    assert_in_delta 180.0, items.fetch("GFCI Outlets (w/ wire)")[:total_cost]
    # switches: 8 * (10 + 25) = 280
    assert_in_delta 280.0, items.fetch("Standard Switches (w/ wire)")[:total_cost]
    # dimmers: 2 * (50 + 25) = 150
    assert_in_delta 150.0, items.fetch("Dimmer Switches (w/ wire)")[:total_cost]
    # fixtures: 6 * (35 + 15) = 300
    assert_in_delta 300.0, items.fetch("Light Fixture Install (labor + hardware)")[:total_cost]
    # recessed: 4 * 55 = 220
    assert_in_delta 220.0, items.fetch("Recessed Lights")[:total_cost]
    # ceiling fan: 1 * (200 + 15 + 25) = 240
    assert_in_delta 240.0, items.fetch("Ceiling Fan Install (labor + hardware + wire)")[:total_cost]

    # material totals = 370 + 180 + 280 + 150 + 300 + 220 + 240 + 200 (permit) + 150 (equip) = 2090
    assert_in_delta 2090.0, result[:total_material_cost]

    # labor: fan 1*(200/65) + outlet 10*0.75 + gfci 3*1.0 + switch 8*0.5 +
    #        dimmer 2*0.75 + fixture 6*(35/65) + recessed 4*1.5
    #      = 3.0769 + 7.5 + 3 + 4 + 1.5 + 3.2308 + 6
    #      = 28.3077 hours, * 1.0 complexity
    assert_in_delta 28.3, result[:labor_hours], 0.1
  end

  test "panel upgrade 200A with no permit pre-1960 2-story applies age+story multiplier" do
    result = MaterialListGenerator.call(
      trade:    "electrical",
      criteria: {
        serviceType: "panel",
        amperage:    "200",
        homeAge:     "pre-1960",
        stories:     2,
        permit:      "no"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert_in_delta 550.0, items.fetch("200A Panel Upgrade")[:total_cost]
    assert_in_delta 250.0, items.fetch("Breakers, Connectors & Misc")[:total_cost]
    refute items.key?("Electrical Permit") # explicit "no" excludes permit

    # total: 550 + 250 + 150 (equip) = 950
    assert_in_delta 950.0, result[:total_material_cost]
    # complexity: 2.0 age * 1.15 story = 2.3
    assert_in_delta 2.3, result[:complexity_multiplier], 0.001
    # labor: 10 hours panel * 2.3 complexity = 23.0
    assert_in_delta 23.0, result[:labor_hours], 0.01
  end

  test "full rewire 2000 sqft 200A 1990+ 1-story" do
    result = MaterialListGenerator.call(
      trade:    "electrical",
      criteria: {
        serviceType:   "rewire",
        squareFootage: 2000,
        amperage:      "200"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # rewire: 2000 * 11.50 = 23000
    rewire = items.fetch("Full Rewire (2000.0 sqft)")
    assert_in_delta 23_000.0, rewire[:total_cost]
    assert_in_delta 550.0, items.fetch("200A Panel")[:total_cost]
    assert_in_delta 250.0, items.fetch("Breakers, Connectors & Misc")[:total_cost]

    # 23000 + 550 + 250 + 200 (permit) + 150 (equip) = 24150
    assert_in_delta 24_150.0, result[:total_material_cost]
    # rewire hours = (2000/100)*4 = 80, +panel 10 = 90, *1.0 complexity
    assert_in_delta 90.0, result[:labor_hours]
  end

  test "ev charger only with 3 stories" do
    result = MaterialListGenerator.call(
      trade:    "electrical",
      criteria: {
        serviceType: "general",
        evCharger:   "yes",
        stories:     3
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # ev: 350 + 100 = 450
    assert_in_delta 450.0, items.fetch("EV Charger Install + Wire Run")[:total_cost]
    # complexity: age 1.0 * story 1.35 = 1.35
    assert_in_delta 1.35, result[:complexity_multiplier], 0.001
    # labor: 4 * 1.35 = 5.4
    assert_in_delta 5.4, result[:labor_hours], 0.01
    # total: 450 + 200 + 150 = 800
    assert_in_delta 800.0, result[:total_material_cost]
  end

  test "snake_case criteria keys" do
    result = MaterialListGenerator.call(
      trade:    "electrical",
      criteria: {
        service_type:   "general",
        square_footage: 1500,
        outlet_count:   5,
        home_age:       "1960-1990",
        permit:         "yes"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert_in_delta 185.0, items.fetch("Standard Outlets (w/ wire)")[:total_cost] # 5*(12+25)
    assert items.key?("Electrical Permit") # "yes" adds
    # complexity: 1.25 age * 1.0 story = 1.25
    assert_in_delta 1.25, result[:complexity_multiplier], 0.001
    # labor: 5*0.75 = 3.75, * 1.25 = 4.6875, rounded to 1dp = 4.7
    assert_in_delta 4.7, result[:labor_hours], 0.01
  end
end
