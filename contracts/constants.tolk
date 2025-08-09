const gasForBurn = 6700;
const gasForTransfer = 11000;
const minTonsForStorage = ton("0.01"); // This should use https://github.com/tact-lang/tact/issues/2336 in the future
const Basechain = 0;

// This is an approximate value. Real one must be less than this, and it is checked in tests.
const walletStateInitCells = 30;
const walletStateInitBits = 20000;