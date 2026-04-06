import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface DashboardSummary {
  stats: {
    availableBalance: number;
    totalDebt: number;
    monthlyExpenses: number;
    totalAssets: number;
  };
  recentExpenses: any[];
}

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private http = inject(HttpClient);
  private apiUrl = environment.apiUrl;

  getDashboardSummary(): Observable<DashboardSummary> {
    return this.http.get<DashboardSummary>(`${this.apiUrl}/dashboard/summary`);
  }

  // --- Bancos y Cuentas ---
  getBanks(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/banks/`);
  }

  getBankAccounts(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/banks/accounts`);
  }

  createBank(bank: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/banks/`, bank);
  }

  updateBank(id: number, bank: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/banks/${id}`, bank);
  }

  deleteBank(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/banks/${id}`);
  }

  createBankAccount(account: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/banks/accounts`, account);
  }

  updateBankAccount(id: number, account: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/banks/accounts/${id}`, account);
  }

  deleteBankAccount(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/banks/accounts/${id}`);
  }

  // --- Gastos ---
  getExpenses(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/expenses/`);
  }

  getCategories(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/expenses/categories`);
  }

  createExpense(expense: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/expenses/`, expense);
  }

  analyzeExpenseReceipt(formData: FormData): Observable<any> {
    return this.http.post(`${this.apiUrl}/expenses/analyze-receipt`, formData);
  }

  downloadExpenseReceipt(expenseId: number): Observable<Blob> {
    return this.http.get(`${this.apiUrl}/expenses/${expenseId}/receipt`, {
      responseType: 'blob'
    });
  }

  // --- Planificación ---
  getPlanning(month: number, year: number): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/planning/?month=${month}&year=${year}`);
  }

  savePlanning(plan: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/planning/`, plan);
  }

  // --- Tarjetas y Préstamos ---
  getCards(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/cards_loans/cards`);
  }

  getLoans(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/cards_loans/loans`);
  }

  createCard(card: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/cards_loans/cards`, card);
  }

  createLoan(loan: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/cards_loans/loans`, loan);
  }

  // --- Activos e Ingresos ---
  getAssets(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/assets_income/assets`);
  }

  getIncome(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/assets_income/income`);
  }

  createAsset(asset: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/assets_income/assets`, asset);
  }

  createIncome(income: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/assets_income/income`, income);
  }

  // --- Deudores ---
  getDebtors(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/debtors/`);
  }

  createDebtor(debtor: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/debtors/`, debtor);
  }

  updateDebtorStatus(id: number, data: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/debtors/${id}`, data);
  }

  // --- Miembros de la Familia ---
  getFamilyMembers(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/family/`);
  }

  createFamilyMember(member: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/family/`, member);
  }

  updateFamilyMember(id: number, member: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/family/${id}`, member);
  }

  deleteFamilyMember(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/family/${id}`);
  }
}
