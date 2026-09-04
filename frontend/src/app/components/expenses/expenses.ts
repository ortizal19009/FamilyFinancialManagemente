import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService, PaginatedResult } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';
import { ConfirmService } from '../../services/confirm.service';

@Component({
  selector: 'app-expenses',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './expenses.html',
  styleUrl: './expenses.scss'
})
export class ExpensesComponent implements OnInit {
  private apiService = inject(ApiService);
  private authService = inject(AuthService);
  private confirmService = inject(ConfirmService);

  currentUser = this.authService.currentUser;
  expenses: any[] = [];
  categories: any[] = [];
  cards: any[] = [];
  accounts: any[] = [];

  searchText = '';
  page = 1;
  perPage = 10;
  totalItems = 0;
  totalPages = 0;
  loadingExpenses = false;
  private searchTimer: ReturnType<typeof setTimeout> | null = null;

  newExpense = {
    description: '',
    payment_method: 'Efectivo',
    expense_date: new Date().toISOString().split('T')[0],
    card_id: null,
    bank_account_id: null,
    items: [
      {
        category_id: null,
        amount: null
      }
    ]
  };

  loading = false;
  analyzingReceipt = false;
  editingExpenseId: number | null = null;
  successMsg = '';
  errorMsg = '';
  selectedReceipt: File | null = null;
  receiptAnalysis: any | null = null;

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.loadExpenses();
    this.apiService.getCategories().subscribe(data => this.categories = data);
    this.apiService.getCards().subscribe(data => this.cards = data);
    this.apiService.getBankAccounts().subscribe(data => this.accounts = data);
  }

  loadExpenses() {
    this.loadingExpenses = true;
    this.apiService.getExpenses({
      search: this.searchText || undefined,
      page: this.page,
      per_page: this.perPage,
    }).subscribe({
      next: (data) => {
        const result = data as PaginatedResult<any>;
        if (Array.isArray(result)) {
          this.expenses = result;
          this.totalItems = result.length;
          this.totalPages = this.totalItems > 0 ? 1 : 0;
        } else {
          this.expenses = result.items;
          this.totalItems = result.total;
          this.totalPages = result.pages;
        }
        this.loadingExpenses = false;
      },
      error: () => {
        this.expenses = [];
        this.totalItems = 0;
        this.totalPages = 0;
        this.loadingExpenses = false;
      }
    });
  }

  onSearchInput() {
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => {
      this.page = 1;
      this.loadExpenses();
    }, 350);
  }

  goToPage(target: number) {
    if (target < 1 || target > this.totalPages || target === this.page) {
      return;
    }
    this.page = target;
    this.loadExpenses();
  }

  onSubmit() {
    this.loading = true;
    this.newExpense.card_id = this.usesCardPayment() ? this.newExpense.card_id : null;
    this.newExpense.bank_account_id = this.usesAccountPayment() ? this.newExpense.bank_account_id : null;

    if (this.editingExpenseId !== null) {
      this.apiService.updateExpense(this.editingExpenseId, this.newExpense).subscribe({
        next: () => {
          this.successMsg = 'Gasto actualizado correctamente';
          this.resetForm();
          this.loadData();
          this.loading = false;
          setTimeout(() => this.successMsg = '', 3000);
        },
        error: (err) => {
          this.errorMsg = err?.error?.msg || 'Error al actualizar el gasto';
          this.loading = false;
          setTimeout(() => this.errorMsg = '', 3000);
        }
      });
      return;
    }

    const formData = new FormData();
    formData.append('payload', JSON.stringify(this.newExpense));
    if (this.selectedReceipt) {
      formData.append('receipt', this.selectedReceipt);
    }

    this.apiService.createExpense(formData).subscribe({
      next: (res) => {
        this.successMsg = 'Gasto registrado correctamente';
        this.resetForm();
        this.loadData();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (err) => {
        this.errorMsg = 'Error al registrar el gasto';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  resetForm() {
    this.newExpense = {
      description: '',
      payment_method: 'Efectivo',
      expense_date: new Date().toISOString().split('T')[0],
      card_id: null,
      bank_account_id: null,
      items: [
        {
          category_id: null,
          amount: null
        }
      ]
    };
    this.selectedReceipt = null;
    this.receiptAnalysis = null;
    this.editingExpenseId = null;
  }

  addExpenseItem() {
    this.newExpense.items.push({
      category_id: null,
      amount: null
    });
  }

  removeExpenseItem(index: number) {
    if (this.newExpense.items.length === 1) {
      return;
    }

    this.newExpense.items.splice(index, 1);
  }

  getExpenseTotal(): number {
    return this.newExpense.items.reduce((total, item) => total + Number(item.amount || 0), 0);
  }

  hasDuplicateCategories(): boolean {
    const categoryIds = this.newExpense.items
      .map(item => item.category_id)
      .filter(categoryId => categoryId !== null && categoryId !== undefined && categoryId !== '');

    return new Set(categoryIds).size !== categoryIds.length;
  }

  onReceiptSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    this.selectedReceipt = file;
    this.receiptAnalysis = null;
  }

  clearReceipt() {
    this.selectedReceipt = null;
    this.receiptAnalysis = null;
  }

  usesCardPayment(): boolean {
    return this.newExpense.payment_method === 'Tarjeta Crédito' || this.newExpense.payment_method === 'Tarjeta Débito';
  }

  usesAccountPayment(): boolean {
    return this.newExpense.payment_method === 'Banca Móvil';
  }

  onPaymentMethodChange() {
    if (!this.usesCardPayment()) {
      this.newExpense.card_id = null;
    }
    if (!this.usesAccountPayment()) {
      this.newExpense.bank_account_id = null;
    }
  }

  getSelectedCard(): any | null {
    return this.cards.find(card => card.id === this.newExpense.card_id) ?? null;
  }

  getSelectedAccount(): any | null {
    return this.accounts.find(account => account.id === this.newExpense.bank_account_id) ?? null;
  }

  analyzeReceipt() {
    if (!this.selectedReceipt) {
      this.errorMsg = 'Primero selecciona un comprobante';
      setTimeout(() => this.errorMsg = '', 3000);
      return;
    }

    const formData = new FormData();
    formData.append('receipt', this.selectedReceipt);

    this.analyzingReceipt = true;
    this.apiService.analyzeExpenseReceipt(formData).subscribe({
      next: (analysis) => {
        this.receiptAnalysis = analysis;
        this.analyzingReceipt = false;
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'No se pudo analizar el comprobante';
        this.analyzingReceipt = false;
        setTimeout(() => this.errorMsg = '', 4000);
      }
    });
  }

  applyReceiptAnalysis() {
    if (!this.receiptAnalysis) {
      return;
    }

    if (this.receiptAnalysis.description) {
      this.newExpense.description = this.receiptAnalysis.description;
    }

    if (this.receiptAnalysis.expense_date) {
      this.newExpense.expense_date = this.receiptAnalysis.expense_date;
    }

    if (Array.isArray(this.receiptAnalysis.items) && this.receiptAnalysis.items.length > 0) {
      this.newExpense.items = this.receiptAnalysis.items.map((item: any) => ({
        category_id: item.category_id ?? null,
        amount: item.amount ?? null
      }));
    } else if (this.receiptAnalysis.total_amount) {
      this.newExpense.items = [
        {
          category_id: this.newExpense.items[0]?.category_id ?? null,
          amount: this.receiptAnalysis.total_amount
        }
      ];
    }
  }

  openReceipt(expense: any) {
    const expenseId = expense?.receipt?.expense_id;
    if (!expenseId) {
      return;
    }

    this.apiService.downloadExpenseReceipt(expenseId).subscribe({
      next: (blob) => {
        const url = URL.createObjectURL(blob);
        window.open(url, '_blank');
        setTimeout(() => URL.revokeObjectURL(url), 60000);
      },
      error: () => {
        this.errorMsg = 'No se pudo abrir el comprobante';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  startEditExpense(expense: any) {
    this.editingExpenseId = expense.id;
    this.newExpense = {
      description: expense.description ?? '',
      payment_method: expense.payment_method ?? 'Efectivo',
      expense_date: expense.expense_date ?? new Date().toISOString().split('T')[0],
      card_id: expense.card_id ?? null,
      bank_account_id: expense.bank_account_id ?? null,
      items: (expense.items?.length ? expense.items : [{
        category_id: expense.category_id ?? null,
        amount: expense.total_amount ?? expense.amount ?? null
      }]).map((item: any) => ({
        category_id: item.category_id ?? null,
        amount: item.amount ?? null
      }))
    };
    this.selectedReceipt = null;
    this.receiptAnalysis = null;
    this.onPaymentMethodChange();
  }

  cancelEditExpense() {
    this.resetForm();
  }

  deleteExpense(expense: any) {
    this.confirmService.confirm({
      title: 'Eliminar gasto',
      message: `¿Deseas eliminar el gasto "${expense.description}"?`,
      confirmLabel: 'Eliminar'
    }).subscribe(confirmed => {
      if (!confirmed) {
        return;
      }

      this.apiService.deleteExpense(expense.id).subscribe({
        next: () => {
          this.successMsg = 'Gasto eliminado correctamente';
          if (this.editingExpenseId === expense.id) {
            this.resetForm();
          }
          if (this.expenses.length === 1 && this.page > 1) {
            this.page -= 1;
          }
          this.loadExpenses();
          setTimeout(() => this.successMsg = '', 3000);
        },
        error: (error) => {
          this.errorMsg = error?.error?.msg || 'Error al eliminar el gasto';
          setTimeout(() => this.errorMsg = '', 3000);
        }
      });
    });
  }
}
