import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface DashboardSummary {
  stats: {
    availableBalance: number;
    totalDebt: number;
    monthlyExpenses: number;
    totalAssets: number;
    investmentsCurrentValue: number;
    investmentsInvestedAmount: number;
  };
  recentExpenses: any[];
}

export type ReportType =
  | 'summary'
  | 'movements'
  | 'accounts'
  | 'expenses'
  | 'planning'
  | 'expenses-category'
  | 'cards'
  | 'loans'
  | 'investments'
  | 'assets'
  | 'debts'
  | 'net-worth'
  | 'audit';

export type ReportFormat = 'pdf' | 'xml' | 'csv' | 'xlsx';

export interface ReportExportParams {
  type: ReportType;
  format: ReportFormat;
  date_from?: string;
  date_to?: string;
  month?: number;
  year?: number;
}

export interface ExpenseListParams {
  search?: string;
  from?: string;
  to?: string;
  category_id?: number;
  payment_method?: string;
  page?: number;
  per_page?: number;
}

export interface PaginatedResult<T> {
  items: T[];
  page: number;
  per_page: number;
  total: number;
  pages: number;
}

export interface SearchPageParams {
  search?: string;
  page?: number;
  per_page?: number;
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

  exportReport(params: ReportExportParams): Observable<Blob> {
    let httpParams = new HttpParams()
      .set('type', params.type)
      .set('format', params.format);

    if (params.date_from) {
      httpParams = httpParams.set('date_from', params.date_from);
    }
    if (params.date_to) {
      httpParams = httpParams.set('date_to', params.date_to);
    }
    if (params.month) {
      httpParams = httpParams.set('month', params.month);
    }
    if (params.year) {
      httpParams = httpParams.set('year', params.year);
    }

    return this.http.get(`${this.apiUrl}/reports/export`, {
      params: httpParams,
      responseType: 'blob'
    });
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
  getExpenses(params?: ExpenseListParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/expenses/`,
      { params: this._buildExpenseParams(params) }
    );
  }

  private _listParams(base: HttpParams, params?: SearchPageParams): HttpParams {
    if (!params) {
      return base;
    }
    if (params.search) {
      base = base.set('search', params.search);
    }
    if (params.page) {
      base = base.set('page', params.page);
    }
    if (params.per_page) {
      base = base.set('per_page', params.per_page);
    }
    return base;
  }

  private _buildExpenseParams(params?: ExpenseListParams): HttpParams {
    let httpParams = new HttpParams();
    if (!params) {
      return httpParams;
    }
    if (params.search) {
      httpParams = httpParams.set('search', params.search);
    }
    if (params.from) {
      httpParams = httpParams.set('from', params.from);
    }
    if (params.to) {
      httpParams = httpParams.set('to', params.to);
    }
    if (params.category_id) {
      httpParams = httpParams.set('category_id', params.category_id);
    }
    if (params.payment_method) {
      httpParams = httpParams.set('payment_method', params.payment_method);
    }
    if (params.page) {
      httpParams = httpParams.set('page', params.page);
    }
    if (params.per_page) {
      httpParams = httpParams.set('per_page', params.per_page);
    }
    return httpParams;
  }

  getCategories(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/expenses/categories`);
  }

  createExpense(expense: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/expenses/`, expense);
  }

  updateExpense(id: number, expense: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/expenses/${id}`, expense);
  }

  deleteExpense(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/expenses/${id}`);
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

  updatePlanning(id: number, plan: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/planning/${id}`, plan);
  }

  deletePlanning(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/planning/${id}`);
  }

  // --- Tarjetas y Préstamos ---
  getCards(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/cards_loans/cards`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  getLoans(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/cards_loans/loans`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  createCard(card: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/cards_loans/cards`, card);
  }

  updateCard(id: number, card: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/cards_loans/cards/${id}`, card);
  }

  deleteCard(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/cards_loans/cards/${id}`);
  }

  createLoan(loan: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/cards_loans/loans`, loan);
  }

  updateLoan(id: number, loan: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/cards_loans/loans/${id}`, loan);
  }

  deleteLoan(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/cards_loans/loans/${id}`);
  }

  // --- Activos e Ingresos ---
  getAssets(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/assets_income/assets`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  getIncome(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/assets_income/income`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  createAsset(asset: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/assets_income/assets`, asset);
  }

  updateAsset(id: number, asset: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/assets_income/assets/${id}`, asset);
  }

  deleteAsset(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/assets_income/assets/${id}`);
  }

  createIncome(income: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/assets_income/income`, income);
  }

  updateIncome(id: number, income: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/assets_income/income/${id}`, income);
  }

  deleteIncome(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/assets_income/income/${id}`);
  }

  // --- Inversiones ---
  getInvestments(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/investments/`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  createInvestment(investment: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/investments/`, investment);
  }

  updateInvestment(id: number, investment: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/investments/${id}`, investment);
  }

  deleteInvestment(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/investments/${id}`);
  }

  // --- Deudores ---
  getDebtors(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/debtors/`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  createDebtor(debtor: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/debtors/`, debtor);
  }

  updateDebtorStatus(id: number, data: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/debtors/${id}`, data);
  }

  deleteDebtor(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/debtors/${id}`);
  }

  getSmallDebts(params?: SearchPageParams): Observable<any[] | PaginatedResult<any>> {
    return this.http.get<any[] | PaginatedResult<any>>(
      `${this.apiUrl}/debtors/small-debts`,
      { params: this._listParams(new HttpParams(), params) }
    );
  }

  createSmallDebt(debt: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/debtors/small-debts`, debt);
  }

  updateSmallDebt(id: number, debt: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/debtors/small-debts/${id}`, debt);
  }

  deleteSmallDebt(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/debtors/small-debts/${id}`);
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
