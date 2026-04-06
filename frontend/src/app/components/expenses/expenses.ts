import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

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

  currentUser = this.authService.currentUser;
  expenses: any[] = [];
  categories: any[] = [];
  cards: any[] = [];
  accounts: any[] = [];

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
  successMsg = '';
  errorMsg = '';
  selectedReceipt: File | null = null;
  receiptAnalysis: any | null = null;

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.apiService.getExpenses().subscribe(data => this.expenses = data);
    this.apiService.getCategories().subscribe(data => this.categories = data);
    this.apiService.getCards().subscribe(data => this.cards = data);
    this.apiService.getBankAccounts().subscribe(data => this.accounts = data);
  }

  onSubmit() {
    this.loading = true;
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
}
