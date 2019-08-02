{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

import Control.Exception
import Control.Monad as P (void)
import qualified Data.List as L
import Data.Typeable
import qualified Foreign.Heap as Heap
import Foreign.List (List)
import qualified Foreign.List as List
import Foreign.Marshal.Pure (Pool)
import qualified Foreign.Marshal.Pure as Manual
import Prelude (return)
import qualified Prelude as P
import Prelude.Linear
import Test.Hspec
import Test.QuickCheck

eqList :: forall a. (Manual.Representable a, Movable a, Eq a) => List a ->. List a ->. Unrestricted Bool
eqList l1 l2 =
    eqUL (move (List.toList l1)) (move (List.toList l2))
  where
    eqUL :: Unrestricted [a] ->. Unrestricted [a] ->. Unrestricted Bool
    eqUL (Unrestricted as1) (Unrestricted as2) = Unrestricted (as1 == as2)

data InjectedError = InjectedError
  deriving (Typeable, Show)

instance Exception InjectedError

main :: IO ()
main = hspec P.$ do
  describe "Off-heap lists" P.$ do
    describe "ofList" P.$ do
      it "is invertible" P.$
        property (\(l :: [Int]) -> unUnrestricted (Manual.withPool $ \pool ->
          let
            check :: Unrestricted [Int] ->. Unrestricted Bool
            check (Unrestricted l') = Unrestricted P.$ l' == l
          in
            check $ move (List.toList $ List.ofList l pool)))

    describe "map" P.$ do
      it "of identity is the identity" P.$
        property (\(l :: [Int]) -> unUnrestricted (Manual.withPool $ \pool ->
          let
            check :: (Pool, Pool, Pool) ->. Unrestricted Bool
            check (pool1, pool2, pool3) =
              eqList
                (List.map (\x -> x) (List.ofList l pool1) pool2)
                (List.ofList l pool3)
          in
            check (dup3 pool)))

    -- XXX: improve the memory corruption test by adding a 'take n' for a random
    -- 'n' before producing an error.
    describe "exceptions" P.$ do
      it "doesn't corrupt memory" P.$ do
        property (\(l :: [Int]) -> do
          let l' = l ++ (throw InjectedError)
          catch @InjectedError
            (P.void P.$ evaluate
               (Manual.withPool $ \pool ->
                   move (List.toList $ List.ofRList l' pool)))
            (\ _ -> return ())
           )


  describe "Off-heap heaps" P.$ do
    describe "sort" P.$ do
      it "sorts" P.$
        property (\(l :: [(Int, ())]) -> Heap.sort l == (L.reverse P.$ L.sort l))
