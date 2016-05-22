{-# LANGUAGE DataKinds, GADTs, PolyKinds, RankNTypes, TypeFamilies #-}
{-# LANGUAGE TypeOperators, UndecidableInstances                   #-}
{-# OPTIONS_GHC -fwarn-incomplete-patterns -Wall #-}
{-# OPTIONS_GHC -fplugin GHC.TypeLits.Normalise #-}
-- | Coercion between Peano Numerals @'Data.Type.Natural.Nat'@ and builtin naturals @'GHC.TypeLits.Nat'@
module Data.Type.Natural.Coercion
       ( -- * Coercion between builtin type-level natural and peano numerals
         FromPeano, ToPeano, sFromPeano, sToPeano,
         -- * Properties of @'FromPeano'@ and @'ToPeano'@.
         fromPeanoInjective, toPeanoInjective,
         -- ** Bijection
         fromToPeano, toFromPeano,
         -- ** Algebraic isomorphisms
         fromPeanoZeroCong, toPeanoZeroCong,
         fromPeanoOneCong,  toPeanoOneCong,
         fromPeanoSuccCong, toPeanoSuccCong,
         fromPeanoPlusCong, toPeanoPlusCong,
         fromPeanoMultCong, toPeanoMultCong,
       )
       where
import Data.Promotion.Prelude.Enum (Succ)

import           Data.Singletons              (Sing, SingI, sing)
import           Data.Singletons.Decide       (Decision (..), (%~))
import           Data.Singletons.Prelude.Enum (Pred, sPred, sSucc)
import           Data.Singletons.Prelude.Num  (SNum (..))
import           Data.Type.Natural            (Nat (S, Z), Sing (SS, SZ))
import           Data.Type.Natural            (plusCongR, succCongEq)
import qualified Data.Type.Natural            as PN
import qualified GHC.TypeLits                 as TL
import           Proof.Equational             ((:=:), (:~:) (Refl), coerce)
import           Proof.Equational             (start, sym, (===), (=~=))
import           Proof.Equational             (because)
import           Unsafe.Coerce                (unsafeCoerce)

type family FromPeano (n :: PN.Nat) :: TL.Nat where
  FromPeano 'Z = 0
  FromPeano ('S n) = Succ (FromPeano n)

type family ToPeano (n :: TL.Nat) :: PN.Nat where
  ToPeano 0 = 'Z
  ToPeano n = 'S (ToPeano (Pred n))

data NatView (n :: TL.Nat) where
  IsZero :: NatView 0
  IsSucc :: Sing n -> NatView (Succ n)

viewNat :: Sing n -> NatView n
viewNat n =
  case n %~ (sing :: Sing 0) of
    Proved Refl -> IsZero
    Disproved _ -> IsSucc (sPred n)

sFromPeano :: Sing n -> Sing (FromPeano n)
sFromPeano SZ = sing
sFromPeano (SS sn) = sSucc (sFromPeano sn)

toPeanoInjective :: ToPeano n :=: ToPeano m -> n :=: m
toPeanoInjective Refl = Refl

trustMe :: a :=: b
trustMe = unsafeCoerce (Refl :: () :=: ())
{-# WARNING trustMe
    "Used unproven type-equalities; This may cause disastrous result..." #-}

toPeanoSuccCong :: Sing n -> ToPeano (Succ n) :=: 'S (ToPeano n)
toPeanoSuccCong _ = unsafeCoerce (Refl :: () :=: ())
  -- We cannot prove this lemma within Haskell, so we assume it a priori.

sToPeano :: Sing n -> Sing (ToPeano n)
sToPeano sn =
  case sn %~ (sing :: Sing 0) of
    Proved Refl  -> SZ
    Disproved _pf -> coerce (sym (toPeanoSuccCong (sPred sn))) (SS (sToPeano (sPred sn)))

-- litSuccInjective :: forall (n :: TL.Nat) (m :: TL.Nat).
--                     Succ n :=: Succ m -> n :=: m
-- litSuccInjective Refl = Refl

toFromPeano :: Sing n -> ToPeano (FromPeano n) :=: n
toFromPeano SZ = Refl
toFromPeano (SS sn) =
  start (sToPeano (sFromPeano (SS sn)))
    =~= sToPeano (sSucc (sFromPeano sn))
    === SS (sToPeano (sFromPeano sn)) `because` toPeanoSuccCong (sFromPeano sn)
    === SS sn                         `because` succCongEq (toFromPeano sn)

congFromPeano :: n :=: m -> FromPeano n :=: FromPeano m
congFromPeano Refl = Refl

congToPeano :: n :=: m -> ToPeano n :=: ToPeano m
congToPeano Refl = Refl

congSucc :: n :=: m -> Succ n :=: Succ m
congSucc Refl = Refl

fromToPeano :: Sing n -> FromPeano (ToPeano n) :=: n
fromToPeano sn  =
  case viewNat sn of
    IsZero    -> Refl
    IsSucc n1 ->
      start (sFromPeano (sToPeano sn))
        =~= sFromPeano (sToPeano (sSucc n1))
        === sFromPeano (SS (sToPeano n1))
              `because` congFromPeano (toPeanoSuccCong n1)
        =~= sSucc (sFromPeano (sToPeano n1))
        === sSucc n1 `because` congSucc (fromToPeano n1)

fromPeanoInjective :: forall n m. (SingI n, SingI m)
                   => FromPeano n :=: FromPeano m -> n :=: m
fromPeanoInjective frEq =
  let sn = sing :: Sing n
      sm = sing :: Sing m
  in start sn
       === sToPeano (sFromPeano sn) `because` sym (toFromPeano sn)
       === sToPeano (sFromPeano sm) `because` congToPeano frEq
       === sm                       `because` toFromPeano sm

fromPeanoSuccCong :: Sing n -> FromPeano ('S n) :=: Succ (FromPeano n)
fromPeanoSuccCong _sn = Refl

fromPeanoPlusCong :: Sing n -> Sing m -> FromPeano (n PN.:+ m) :=: FromPeano n TL.+ FromPeano m
fromPeanoPlusCong SZ _ = Refl
fromPeanoPlusCong (SS sn) sm =
  start (sFromPeano (SS sn %:+ sm))
    =~= sFromPeano (SS (sn %:+ sm))
    === sSucc (sFromPeano (sn %:+ sm))           `because` fromPeanoSuccCong (sn %:+ sm)
    === sSucc (sFromPeano sn  %:+ sFromPeano sm) `because` congSucc (fromPeanoPlusCong sn sm)
    =~= sSucc (sFromPeano sn) %:+ sFromPeano sm
    =~= sFromPeano (SS sn)    %:+ sFromPeano sm

toPeanoPlusCong :: Sing n -> Sing m -> ToPeano (n TL.+ m) :=: ToPeano n PN.:+ ToPeano m
toPeanoPlusCong sn sm =
  case viewNat sn of
    IsZero -> Refl
    IsSucc pn ->
      start (sToPeano (sSucc pn %:+ sm))
        =~= sToPeano (sSucc (pn %:+ sm))
        === SS (sToPeano (pn %:+ sm))
            `because` toPeanoSuccCong (pn %:+ sm)
        === SS (sToPeano pn %:+ sToPeano sm)
            `because` succCongEq (toPeanoPlusCong pn sm)
        =~= SS (sToPeano pn) %:+ sToPeano sm
        === (sToPeano (sSucc pn) %:+ sToPeano sm)
            `because` plusCongR (sToPeano sm) (sym (toPeanoSuccCong pn))
        =~= sToPeano sn %:+ sToPeano sm

fromPeanoZeroCong :: FromPeano 'Z :=: 0
fromPeanoZeroCong = Refl

toPeanoZeroCong :: ToPeano 0 :=: 'Z
toPeanoZeroCong = Refl

fromPeanoOneCong :: FromPeano PN.One :=: 1
fromPeanoOneCong = Refl

toPeanoOneCong :: ToPeano 1 :=: PN.One
toPeanoOneCong = Refl

natPlusCongR :: Sing r -> n :=: m -> n TL.+ r :=: m TL.+ r
natPlusCongR _ Refl = Refl

fromPeanoMultCong :: Sing n -> Sing m -> FromPeano (n PN.:* m) :=: FromPeano n TL.* FromPeano m
fromPeanoMultCong SZ _ = Refl
fromPeanoMultCong (SS psn) sm =
  start (sFromPeano (SS psn %:* sm))
    =~= sFromPeano (psn %:* sm %:+ sm)
    === sFromPeano (psn %:* sm) %:+ sFromPeano sm
        `because` fromPeanoPlusCong (psn %:* sm) sm
    === sFromPeano psn %:* sFromPeano sm %:+ sFromPeano sm
        `because` natPlusCongR (sFromPeano sm) (fromPeanoMultCong psn sm)
    =~= sSucc (sFromPeano psn) %:* sFromPeano sm
    =~= sFromPeano (SS psn)    %:* sFromPeano sm


toPeanoMultCong :: Sing n -> Sing m -> ToPeano (n PN.:* m) :=: ToPeano n PN.:* ToPeano m
toPeanoMultCong sn sm =
  case viewNat sn of
    IsZero -> Refl
    IsSucc psn ->
      start (sToPeano (sSucc psn %:* sm))
        =~= sToPeano (psn %:* sm %:+ sm)
        === sToPeano (psn %:* sm) %:+ sToPeano sm
            `because` toPeanoPlusCong (psn %:* sm) sm
        === sToPeano psn %:* sToPeano sm %:+ sToPeano sm
            `because` plusCongR (sToPeano sm) (toPeanoMultCong psn sm)
        =~= SS (sToPeano psn) %:* sToPeano sm
        === sToPeano (sSucc psn) %:* sToPeano sm
            `because` PN.multCongR (sToPeano sm) (sym (toPeanoSuccCong psn))

