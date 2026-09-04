import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService, PaginatedResult } from '../../services/api.service';
import { ConfirmService } from '../../services/confirm.service';
import { AppPaginationComponent } from '../shared/pagination/pagination';

@Component({
  selector: 'app-debtors',
  standalone: true,
  imports: [CommonModule, FormsModule, AppPaginationComponent],
  templateUrl: './debtors.html',
  styleUrl: './debtors.scss'
})
export class DebtorsComponent implements OnInit {
  private apiService = inject(ApiService);
  private confirmService = inject(ConfirmService);

  debtors: any[] = [];
  smallDebts: any[] = [];
  editingDebtorId: number | null = null;
  editingSmallDebtId: number | null = null;

  debtorsSearch = '';
  debtorsPage = 1;
  debtorsPerPage = 8;
  debtorsTotal = 0;
  debtorsPages = 0;
  loadingDebtors = false;

  smallDebtsSearch = '';
  smallDebtsPage = 1;
  smallDebtsPerPage = 8;
  smallDebtsTotal = 0;
  smallDebtsPages = 0;
  loadingSmallDebtsList = false;

  private debtorsSearchTimer: ReturnType<typeof setTimeout> | null = null;
  private smallDebtsSearchTimer: ReturnType<typeof setTimeout> | null = null;

  newDebtor = {
    name: '',
    amount_owed: 0,
    description: '',
    due_date: '',
    status: 'pendiente'
  };

  newSmallDebt = {
    lender_name: '',
    amount: 0,
    description: '',
    borrowed_date: '',
    due_date: '',
    status: 'pendiente'
  };

  loadingDebtor = false;
  loadingSmallDebt = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.loadDebtors();
    this.loadSmallDebts();
  }

  private applyPageResult<T>(data: any[] | PaginatedResult<T>, setter: (items: T[]) => void): { total: number; pages: number } {
    if (Array.isArray(data)) {
      setter(data);
      return { total: data.length, pages: data.length > 0 ? 1 : 0 };
    }
    setter(data.items);
    return { total: data.total, pages: data.pages };
  }

  loadDebtors() {
    this.loadingDebtors = true;
    this.apiService.getDebtors({
      search: this.debtorsSearch || undefined,
      page: this.debtorsPage,
      per_page: this.debtorsPerPage,
    }).subscribe({
      next: (data) => {
        const result = this.applyPageResult(data, items => this.debtors = items);
        this.debtorsTotal = result.total;
        this.debtorsPages = result.pages;
        this.loadingDebtors = false;
      },
      error: () => {
        this.debtors = [];
        this.debtorsTotal = 0;
        this.debtorsPages = 0;
        this.loadingDebtors = false;
      }
    });
  }

  loadSmallDebts() {
    this.loadingSmallDebtsList = true;
    this.apiService.getSmallDebts({
      search: this.smallDebtsSearch || undefined,
      page: this.smallDebtsPage,
      per_page: this.smallDebtsPerPage,
    }).subscribe({
      next: (data) => {
        const result = this.applyPageResult(data, items => this.smallDebts = items);
        this.smallDebtsTotal = result.total;
        this.smallDebtsPages = result.pages;
        this.loadingSmallDebtsList = false;
      },
      error: () => {
        this.smallDebts = [];
        this.smallDebtsTotal = 0;
        this.smallDebtsPages = 0;
        this.loadingSmallDebtsList = false;
      }
    });
  }

  onSearchDebtorsInput() {
    if (this.debtorsSearchTimer) {
      clearTimeout(this.debtorsSearchTimer);
    }
    this.debtorsSearchTimer = setTimeout(() => {
      this.debtorsPage = 1;
      this.loadDebtors();
    }, 350);
  }

  onSearchSmallDebtsInput() {
    if (this.smallDebtsSearchTimer) {
      clearTimeout(this.smallDebtsSearchTimer);
    }
    this.smallDebtsSearchTimer = setTimeout(() => {
      this.smallDebtsPage = 1;
      this.loadSmallDebts();
    }, 350);
  }

  goToDebtorsPage(page: number) {
    this.debtorsPage = page;
    this.loadDebtors();
  }

  goToSmallDebtsPage(page: number) {
    this.smallDebtsPage = page;
    this.loadSmallDebts();
  }

  onSubmitDebtor() {
    this.loadingDebtor = true;
    const request = this.editingDebtorId === null
      ? this.apiService.createDebtor(this.newDebtor)
      : this.apiService.updateDebtorStatus(this.editingDebtorId, this.newDebtor);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingDebtorId === null
          ? 'Deudor registrado correctamente'
          : 'Deudor actualizado correctamente';
        this.resetDebtorForm();
        this.loadData();
        this.loadingDebtor = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingDebtorId === null
          ? 'Error al registrar al deudor'
          : 'Error al actualizar al deudor';
        this.loadingDebtor = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onSubmitSmallDebt() {
    this.loadingSmallDebt = true;
    const request = this.editingSmallDebtId === null
      ? this.apiService.createSmallDebt(this.newSmallDebt)
      : this.apiService.updateSmallDebt(this.editingSmallDebtId, this.newSmallDebt);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingSmallDebtId === null
          ? 'Deuda registrada correctamente'
          : 'Deuda actualizada correctamente';
        this.resetSmallDebtForm();
        this.loadData();
        this.loadingSmallDebt = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingSmallDebtId === null
          ? 'Error al registrar la deuda'
          : 'Error al actualizar la deuda';
        this.loadingSmallDebt = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditDebtor(debtor: any) {
    this.editingDebtorId = debtor.id;
    this.newDebtor = {
      name: debtor.name ?? '',
      amount_owed: debtor.amount_owed ?? 0,
      description: debtor.description ?? '',
      due_date: debtor.due_date ?? '',
      status: debtor.status ?? 'pendiente'
    };
  }

  onDeleteDebtor(debtor: any) {
    this.confirmService.confirm({
      title: 'Eliminar deudor',
      message: `¿Deseas eliminar a "${debtor.name}"?`,
      confirmLabel: 'Eliminar'
    }).subscribe(confirmed => {
      if (!confirmed) {
        return;
      }

      this.apiService.deleteDebtor(debtor.id).subscribe({
        next: () => {
          if (this.editingDebtorId === debtor.id) {
            this.resetDebtorForm();
          }
          this.successMsg = 'Deudor eliminado correctamente';
          if (this.debtors.length === 1 && this.debtorsPage > 1) {
            this.debtorsPage -= 1;
          }
          this.loadDebtors();
          setTimeout(() => this.successMsg = '', 3000);
        },
        error: () => {
          this.errorMsg = 'Error al eliminar al deudor';
          setTimeout(() => this.errorMsg = '', 3000);
        }
      });
    });
  }

  onEditSmallDebt(debt: any) {
    this.editingSmallDebtId = debt.id;
    this.newSmallDebt = {
      lender_name: debt.lender_name ?? '',
      amount: debt.amount ?? 0,
      description: debt.description ?? '',
      borrowed_date: debt.borrowed_date ?? '',
      due_date: debt.due_date ?? '',
      status: debt.status ?? 'pendiente'
    };
  }

  onDeleteSmallDebt(debt: any) {
    this.confirmService.confirm({
      title: 'Eliminar deuda',
      message: `¿Deseas eliminar la deuda con "${debt.lender_name}"?`,
      confirmLabel: 'Eliminar'
    }).subscribe(confirmed => {
      if (!confirmed) {
        return;
      }

      this.apiService.deleteSmallDebt(debt.id).subscribe({
        next: () => {
          if (this.editingSmallDebtId === debt.id) {
            this.resetSmallDebtForm();
          }
          this.successMsg = 'Deuda eliminada correctamente';
          if (this.smallDebts.length === 1 && this.smallDebtsPage > 1) {
            this.smallDebtsPage -= 1;
          }
          this.loadSmallDebts();
          setTimeout(() => this.successMsg = '', 3000);
        },
        error: () => {
          this.errorMsg = 'Error al eliminar la deuda';
          setTimeout(() => this.errorMsg = '', 3000);
        }
      });
    });
  }

  resetDebtorForm() {
    this.editingDebtorId = null;
    this.newDebtor = {
      name: '',
      amount_owed: 0,
      description: '',
      due_date: '',
      status: 'pendiente'
    };
  }

  resetSmallDebtForm() {
    this.editingSmallDebtId = null;
    this.newSmallDebt = {
      lender_name: '',
      amount: 0,
      description: '',
      borrowed_date: '',
      due_date: '',
      status: 'pendiente'
    };
  }

  getTotalOwed(): number {
    return this.debtors
      .filter(d => d.status === 'pendiente')
      .reduce((acc, curr) => acc + curr.amount_owed, 0);
  }

  getTotalSmallDebts(): number {
    return this.smallDebts
      .filter(d => d.status === 'pendiente')
      .reduce((acc, curr) => acc + curr.amount, 0);
  }
}
