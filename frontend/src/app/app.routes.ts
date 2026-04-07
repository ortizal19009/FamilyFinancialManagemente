import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login';
import { RegisterComponent } from './components/register/register';
import { DashboardComponent } from './components/dashboard/dashboard';
import { ExpensesComponent } from './components/expenses/expenses';
import { BanksComponent } from './components/banks/banks';
import { CardsLoansComponent } from './components/cards-loans/cards-loans';
import { PlanningComponent } from './components/planning/planning';
import { AssetsIncomeComponent } from './components/assets-income/assets-income';
import { DebtorsComponent } from './components/debtors/debtors';
import { AdminUsersComponent } from './components/admin-users/admin-users';
import { FamilyMembersComponent } from './components/family-members/family-members';
import { InvestmentsComponent } from './components/investments/investments';
import { authGuard } from './guards/auth.guard';
import { guestGuard } from './guards/guest.guard';

export const routes: Routes = [
  { path: 'login', component: LoginComponent, canActivate: [guestGuard] },
  { path: 'register', component: RegisterComponent, canActivate: [guestGuard] },
  { path: 'dashboard', component: DashboardComponent, canActivate: [authGuard] },
  { path: 'expenses', component: ExpensesComponent, canActivate: [authGuard] },
  { path: 'banks', component: BanksComponent, canActivate: [authGuard] },
  { path: 'cards', component: CardsLoansComponent, canActivate: [authGuard] },
  { path: 'loans', component: CardsLoansComponent, canActivate: [authGuard] },
  { path: 'planning', component: PlanningComponent, canActivate: [authGuard] },
  { path: 'assets', component: AssetsIncomeComponent, canActivate: [authGuard] },
  { path: 'income', component: AssetsIncomeComponent, canActivate: [authGuard] },
  { path: 'debtors', component: DebtorsComponent, canActivate: [authGuard] },
  { path: 'investments', component: InvestmentsComponent, canActivate: [authGuard] },
  { path: 'family', component: FamilyMembersComponent, canActivate: [authGuard] },
  { path: 'admin/users', component: AdminUsersComponent, canActivate: [authGuard] },
  { path: '', redirectTo: '/login', pathMatch: 'full' }
];
