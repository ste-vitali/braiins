// Copyright (C) 2019  Braiins Systems s.r.o.
//
// This file is part of Braiins Open-Source Initiative (BOSI).
//
// BOSI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Please, keep in mind that we may also license BOSI or any part thereof
// under a proprietary license. For more information on the terms and conditions
// of such proprietary license or if you have any other questions, please
// contact us at opensource@braiins.com.

pub mod work_generation;

use super::*;

#[test]
fn test_hchain_ctl_instance() {
    let gpio_mgr = gpio::ControlPinManager::new();
    let voltage_ctrl_backend = power::I2cBackend::new(0);
    let voltage_ctrl_backend = power::SharedBackend::new(voltage_ctrl_backend);
    let (monitor_sender, _monitor_receiver) = mpsc::unbounded();
    let hash_chain = HashChain::new(
        &gpio_mgr,
        voltage_ctrl_backend,
        config::S9_HASHBOARD_INDEX,
        MidstateCount::new(1),
        config::ASIC_DIFFICULTY,
        monitor_sender,
    );
    match hash_chain {
        Ok(_) => assert!(true),
        Err(e) => assert!(false, "Failed to instantiate hash chain, error: {}", e),
    }
}

#[test]
fn test_calc_baud_div_correct_baud_rate_bm1387() {
    // these are sample baud rates for communicating with BM1387 chips
    let correct_bauds_and_divs = [
        (115_200usize, 26usize),
        (460_800, 6),
        (1_500_000, 1),
        (3_000_000, 0),
    ];
    for (baud_rate, baud_div) in correct_bauds_and_divs.iter() {
        let (baud_clock_div, actual_baud_rate) = calc_baud_clock_div(
            *baud_rate,
            CHIP_OSC_CLK_HZ,
            bm1387::CHIP_OSC_CLK_BASE_BAUD_DIV,
        )
        .unwrap();
        assert_eq!(
            baud_clock_div, *baud_div,
            "Calculated baud divisor doesn't match, requested: {} baud, actual: {} baud",
            baud_rate, actual_baud_rate
        )
    }
}

/// Test higher baud rate than supported
#[test]
fn test_calc_baud_div_over_baud_rate_bm1387() {
    let result = calc_baud_clock_div(
        3_500_000,
        CHIP_OSC_CLK_HZ,
        bm1387::CHIP_OSC_CLK_BASE_BAUD_DIV,
    );
    assert!(
        result.is_err(),
        "Baud clock divisor unexpectedly calculated!"
    );
}

/// Test work_time computation
#[test]
fn test_work_time_computation() {
    // you need to recalc this if you change asic diff or fpga freq
    assert_eq!(
        secs_to_fpga_ticks(calculate_work_delay_for_pll(1, 650_000_000)),
        36296
    );
}
