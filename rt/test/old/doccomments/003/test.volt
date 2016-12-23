//T compiles:no
module test;

// Should be fine, not sure if this will do anything
/**
 * @{
 */
void ichi();
void ni();


// Also okay, note that the first comment block is merged with the @{ block

///
/// My cool comment on both functions.
///
/**
 * @{
 */
void san();
void yon();
/**
 * @}
 */ 
  
int main()  // Go!
{
	return 0;
}
