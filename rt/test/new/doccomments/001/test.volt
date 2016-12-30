module test;

// Should be fine, not sure if this will do anything
/**
 * @{
 */
fn ichi();
fn ni();
/**
 * @}
 */


// Also okay, note that the first comment block is merged with the @{ block

///
/// My cool comment on both functions.
///
/**
 * @{
 */
fn san();
fn yon();
/**
 * @}
 */ 
  
fn main() i32  // Go!
{
	return 0;
}

