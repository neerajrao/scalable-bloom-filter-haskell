{-|
Module      : ImmutableBloomFilter
Description : Immutable bloom filter that, once initialized, does not
              allow insertion of any more elements.

The main differences between this and MutableBloomFilter are:
    1. the latter can not be used from pure code
    2. the latter allows insertion of elements once initialized.
-}

module ImmutableBloomFilter (ImmutableBloom,
                             newFromList,
                             size,
                             elem,
                             notElem) where

import Types
import Hash.Hash
import Data.Array.Unboxed (bounds, (!))
import Data.List (genericLength)
import Data.Word (Word32)
import qualified MutableBloomFilter (insert, new, toImmutable)
import Prelude hiding (elem, notElem)

-- | Create an immutable bloom filter.
-- The first argument is the false positive rate desired (between 0 and 1) (P)
-- The second argument is a list of values with which to initialize the filter.
-- Once initialized, no values can be added to an immutable filter.
newFromList :: Hashable a => Double -> [a] -> ImmutableBloom a
newFromList p initList = MutableBloomFilter.toImmutable $ do
    mutableBloom <- MutableBloomFilter.new p (genericLength initList)
    mapM_ (MutableBloomFilter.insert mutableBloom) initList
    return mutableBloom

-- | Returns the total size (M = m*k) in bits of the filter.
size :: ImmutableBloom a -> Word32
size filt = ((1 +) . snd) (bounds (immutBitArray filt))

-- | Given an element to insert, return the corresponding indices that should
-- be set in the filter
getHashIndices :: ImmutableBloom a -> a -> [Word32]
getHashIndices filt element = addSliceOffsets indicesWithinSlice
    where addSliceOffsets = (flip . zipWith) (\indexWithinSlice sliceOffset ->
                                                sliceOffset*bitsPerSlice + indexWithinSlice)
                                             [0..]
          indicesWithinSlice = map (`mod` bitsPerSlice) $ immutHashFns filt element
          bitsPerSlice = immutBitsPerSlice filt

-- | Returns True if the element is in the filter
-- There is a small chance that True will be returned even if the element
-- is NOT in the filter
elem :: ImmutableBloom a -> a -> Bool
elem filt element = all (immutBitArray filt !) (getHashIndices filt element)

-- | Complement of 'elem'.
notElem :: ImmutableBloom a -> a -> Bool
notElem filt = not . elem filt
