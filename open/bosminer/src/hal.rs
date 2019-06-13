use uint;

pub mod s9;

/// Describes actual mining work for submission to a hashing hardware.
/// Starting with merkel_root_lsw the data goes to chunk2 of SHA256.
///
/// NOTE: eventhough, version and extranonce_2 are already included in the midstates, we
/// need them as part of the MiningWork structure. The reason is stratum submission requirements.
/// This may need further refactoring.
/// # TODO
/// Add ntime limit for supporting hardware that can do nTime rolling on its own
#[derive(Clone, Debug)]
pub struct MiningWork {
    /// Version field used for calculating the midstate
    pub version: u32,
    /// Extranonce 2 used for calculating merkelroot
    pub extranonce_2: u32,
    /// Multiple midstates can be generated for each work - these are the full
    pub midstates: Vec<uint::U256>,
    /// least-significant word of merkleroot that goes to chunk2 of SHA256
    pub merkel_root_lsw: u32,
    /// Start value for nTime, hardware may roll nTime further.
    pub ntime: u32,
    /// Network difficulty encoded as nbits (exponent + mantissa - see
    /// https://en.bitcoin.it/wiki/Difficulty)
    pub nbits: u32,
}

/// Represents raw solution from the mining hardware
#[derive(Clone, Debug)]
pub struct MiningWorkSolution {
    /// actual nonce
    pub nonce: u32,
    /// nTime of the solution in case the HW also rolls the nTime field
    pub ntime: Option<u32>,
    /// index of a midstate that corresponds to the found nonce
    pub midstate_idx: usize,
    /// Unique identifier for the solution
    pub solution_id: u32,
}

/// Container with mining work and a corresponding solution received at a particular time
/// This data structure is used when posting work+solution pairs for further submission upstream.
#[derive(Clone, Debug)]
pub struct UniqueMiningWorkSolution {
    /// time stamp when it has been fetched from the solution FIFO
    pub timestamp: std::time::SystemTime,
    /// Original mining work associated with this solution
    pub work: MiningWork,
    /// solution of the PoW puzzle
    pub solution: MiningWorkSolution,
}

/// Holds all hardware-related statistics for a hashchain
pub struct MiningStats {
    /// Number of work items generated for the hardware
    pub work_generated: usize,
    /// Number of stale solutions received from the hardware
    pub stale_solutions: u64,
    /// Unable to feed the hardware fast enough results in duplicate solutions as
    /// multiple chips may process the same mining work
    pub duplicate_solutions: u64,
    /// Keep track of nonces that didn't match with previously received solutions (after
    /// filtering hardware errors, this should really stay at 0, otherwise we have some weird
    /// hardware problem)
    pub mismatched_solution_nonces: u64,
    /// Counter of unique solutions
    pub unique_solutions: u64,
}

impl MiningStats {
    pub fn new() -> Self {
        Self {
            work_generated: 0,
            stale_solutions: 0,
            duplicate_solutions: 0,
            mismatched_solution_nonces: 0,
            unique_solutions: 0,
        }
    }
}

/// Any hardware mining controller should implement at least these methods
pub trait HardwareCtl {
    /// Sends work to the hash chain
    ///
    /// Returns a unique ID that can be used for registering the work within a hardware specific
    /// registry
    fn send_work(&mut self, work: &MiningWork) -> Result<u32, failure::Error>;

    /// Receives 1 MiningWorkSolution
    fn recv_solution(&mut self) -> Result<Option<MiningWorkSolution>, failure::Error>;

    /// Extracts original work ID for a mining solution
    fn get_work_id_from_solution(&self, solution: &MiningWorkSolution) -> u32;

    /// Returns the number of detected chips
    fn get_chip_count(&self) -> usize;
}